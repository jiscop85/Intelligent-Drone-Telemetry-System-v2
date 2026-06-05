#!/usr/bin/env python3
"""Professional PyQt6 Dashboard for Intelligent Drone Telemetry System
Live numeric status cards, historical charts, interactive map, anomaly detection
"""

import json
from dataclasses import asdict

import paho.mqtt.client as mqtt
import pyqtgraph as pg
from PyQt6.QtCore import QObject, QThread, QTimer, Qt, pyqtSignal
from PyQt6.QtWidgets import (
    QApplication, QGridLayout, QHBoxLayout, QLabel, QMainWindow,
    QPushButton, QVBoxLayout, QWidget, QFileDialog
)
from PyQt6.QtWebEngineWidgets import QWebEngineView

from telemetry_store import TelemetryStore, TelemetrySample
from analytics.anomaly_detector import AnomalyDetector

BROKER = "localhost"
TOPIC = "drone/telemetry"

class MqttWorker(QObject):
    sample_received = pyqtSignal(dict)
    status = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self.client = mqtt.Client(
            mqtt.CallbackAPIVersion.VERSION2,
            client_id="drone_dashboard"
        )

    def start(self):
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.connect(BROKER, 1883, 60)
        self.client.loop_forever()

    def on_connect(self, client, userdata, flags, reason_code, properties):
        self.status.emit(f"MQTT connected: {reason_code}")
        client.subscribe(TOPIC, qos=1)

    def on_message(self, client, userdata, msg):
        try:
            data = json.loads(msg.payload.decode("utf-8"))
            self.sample_received.emit(data)
        except Exception:
            pass

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Intelligent Drone Telemetry System")
        self.resize(1600, 950)

        self.store = TelemetryStore(maxlen=5000)
        self.detector = AnomalyDetector()
        self.path_points = []

        root = QWidget()
        self.setCentralWidget(root)

        main = QHBoxLayout(root)
        left = QVBoxLayout()
        right = QVBoxLayout()
        main.addLayout(left, 2)
        main.addLayout(right, 3)

        self.status_bar = QLabel("Disconnected")
        left.addWidget(self.status_bar)

        self.cards = {}
        grid = QGridLayout()
        left.addLayout(grid)

        fields = [
            "GPS", "Altitude", "Battery", "IMU Temp",
            "Velocity", "Wind", "State", "Anomaly"
        ]
        for i, name in enumerate(fields):
            grid.addWidget(QLabel(f"<b>{name}</b>"), i, 0)
            val = QLabel("--")
            val.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
            grid.addWidget(val, i, 1)
            self.cards[name] = val

        self.alt_plot = pg.PlotWidget(title="Relative Altitude")
        self.batt_plot = pg.PlotWidget(title="Battery Percentage")
        self.spd_plot = pg.PlotWidget(title="Ground Speed")

        self.alt_curve = self.alt_plot.plot()
        self.batt_curve = self.batt_plot.plot()
        self.spd_curve = self.spd_plot.plot()

        right.addWidget(self.alt_plot)
        right.addWidget(self.batt_plot)
        right.addWidget(self.spd_plot)

        self.map_view = QWebEngineView()
        left.addWidget(self.map_view, 1)
        self._init_map()

        btn_row = QHBoxLayout()
        left.addLayout(btn_row)

        self.csv_btn = QPushButton("Export CSV")
        self.geojson_btn = QPushButton("Export GeoJSON")
        btn_row.addWidget(self.csv_btn)
        btn_row.addWidget(self.geojson_btn)

        self.csv_btn.clicked.connect(self.export_csv)
        self.geojson_btn.clicked.connect(self.export_geojson)

        self.worker = MqttWorker()
        self.thread = QThread(self)
        self.worker.moveToThread(self.thread)
        self.thread.started.connect(self.worker.start)
        self.worker.sample_received.connect(self.on_sample)
        self.worker.status.connect(self.status_bar.setText)
        self.thread.start()

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.refresh_ui)
        self.timer.start(250)

    def _init_map(self):
        html = """
        <html>
        <head>
            <meta charset="utf-8" />
            <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
            <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
            <style>
                html, body, #map { height: 100%; margin: 0; }
            </style>
        </head>
        <body>
            <div id="map"></div>
            <script>
                const map = L.map('map').setView([0, 0], 2);
                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    maxZoom: 19
                }).addTo(map);

                let poly = L.polyline([], {weight: 4}).addTo(map);

                window.updateTrack = function(points) {
                    poly.setLatLngs(points);
                    if (points.length > 0) {
                        map.setView(points[points.length - 1], 17);
                    }
                };
            </script>
        </body>
        </html>
        """
        self.map_view.setHtml(html)

