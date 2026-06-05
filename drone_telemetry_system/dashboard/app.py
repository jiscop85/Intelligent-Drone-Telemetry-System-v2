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
