# Technology Roadmap & Future Enhancements

## Current State (MVP v2)

✅ **Implemented**
- Real-time C++ telemetry collector with MAVSDK
- MQTT-based data distribution
- Professional PyQt6 dashboard with charts and map
- Anomaly detection (IsolationForest)
- ROS2 bridge for robotics integration
- Live video overlay
- CSV and GeoJSON export

## Phase 1: Data Persistence (Months 1-2)

### 1.1 SQLite Local Storage

**Why**: Persistent flight history, local queries, no cloud dependency

```python
# analytics/flight_database.py (NEW)
from sqlalchemy import create_engine, Column, Float, Integer, String, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

Base = declarative_base()

class TelemetrySample(Base):
    __tablename__ = 'telemetry'
    
    id = Column(Integer, primary_key=True)
    ts_ms = Column(Integer, index=True)
    flight_id = Column(String, index=True)
    lat = Column(Float)
    lon = Column(Float)
    alt_m = Column(Float)
    battery_pct = Column(Float)
    # ... 20+ more columns
    
    def __repr__(self):
        return f"Sample(ts={self.ts_ms}, flight={self.flight_id})"

class FlightDatabase:
    def __init__(self, db_path: str = "data/flights.db"):
        self.engine = create_engine(f'sqlite:///{db_path}')
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
    
    def add_sample(self, sample: TelemetrySample):
        session = self.Session()
        session.add(sample)
        session.commit()
    
    def query_flight(self, flight_id: str):
        session = self.Session()
        return session.query(TelemetrySample)\
            .filter_by(flight_id=flight_id)\
            .order_by(TelemetrySample.ts_ms)\
            .all()
```

**Integration**: Dashboard auto-saves all samples to SQLite

### 1.2 InfluxDB Time-Series Storage (Optional)

**Why**: Efficient time-series compression, built-in downsampling, Grafana integration

```python
# analytics/influx_writer.py (NEW)
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS

class InfluxWriter:
    def __init__(self, url="http://localhost:8086", token="your-token", org="drones"):
        self.client = InfluxDBClient(url=url, token=token, org=org)
        self.write_api = self.client.write_api(write_type=SYNCHRONOUS)
    
    def write_sample(self, sample: dict, bucket: str = "drone-telemetry"):
        point = Point("telemetry")\
            .tag("flight_id", sample['flight_id'])\
            .field("lat", sample['gps']['lat'])\
            .field("lon", sample['gps']['lon'])\
            .field("altitude", sample['altitude_m']['relative'])\
            .field("battery", sample['battery']['percent'])\
            .time(sample['ts_ms'], write_precision='ms')
        
        self.write_api.write(bucket=bucket, record=point)
```

**Docker Compose**:
```yaml
influxdb:
  image: influxdb:latest
  environment:
    INFLUXDB_DB: drone-telemetry
  ports:
    - "8086:8086"
  volumes:
    - influx_data:/var/lib/influxdb2
```

## Phase 2: Flight Replay & Playback (Months 2-3)

### 2.1 Timeline Slider

**Dashboard Feature**: Scrub through recorded flight

```python
# dashboard/app.py (ENHANCED)
self.timeline_slider = QSlider(Qt.Orientation.Horizontal)
self.timeline_slider.setMinimum(0)
self.timeline_slider.setMaximum(len(self.store.samples) - 1)
self.timeline_slider.sliderMoved.connect(self.on_timeline_seek)

def on_timeline_seek(self, index: int):
    if 0 <= index < len(self.store.samples):
        sample = list(self.store.samples)[index]
        self._update_display(sample)
        # Move map to that point
        js = f"window.setMarker({sample.lat}, {sample.lon});"
        self.map_view.page().runJavaScript(js)
```

### 2.2 Replay Speed Control

```python
self.playback_speed = 1.0  # 0.25x, 0.5x, 1.0x, 2.0x, 4.0x
self.replay_timer = QTimer()
self.replay_timer.timeout.connect(self.advance_replay)
self.replay_timer.start(int(100 / self.playback_speed))  # Adjust interval
```
### 3.2 Audio & Visual Alerts

```python
# dashboard/notifications.py (NEW)
from PyQt6.QtMultimedia import QSoundEffect

class NotificationManager:
    def __init__(self):
        self.sound = QSoundEffect()
        self.sound.setSource(QUrl.fromLocalFile("assets/alert.wav"))
    
    def alert(self, alert: Alert):
        if alert.level == AlertLevel.CRITICAL:
            self.sound.play()  # Beep
            self._show_toast(alert.message, "red")
        elif alert.level == AlertLevel.WARNING:
            self._show_toast(alert.message, "orange")
```

### 3.3 Alert Dashboard Tab

```
┌────────────────────────────────────────┐
│ 🔴 ALERTS                              │
├────────────────────────────────────────┤
│ [14:32:45] 🔴 Low Battery (18%)        │
│ [14:31:22] 🟠 High Temperature (62°C)  │
│ [14:30:00] 🟠 GPS Weak (Fix: 2)        │
│ [14:28:15] 🟠 Anomaly Detected         │
│                                        │
│ ☐ Enable Audio   ☐ Pause Alerts       │
└────────────────────────────────────────┘
```

## Phase 4: Mission Planning & Waypoints (Months 4-5)

### 4.1 Waypoint Display

```python
# dashboard/mission_viewer.py (NEW)
class MissionViewer:
    def __init__(self, map_view: QWebEngineView):
        self.waypoints = []
        self.map_view = map_view
    
    def load_mission(self, mission_file: str):
        """Load QGroundControl .plan file"""
        with open(mission_file) as f:
            mission = json.load(f)
        
        self.waypoints = [
            (wp['DoJump']['Lat'], wp['DoJump']['Lon'])
            for wp in mission['items']
        ]
    
    def draw_mission(self):
        js = """
        let waypoints = """ + json.dumps(self.waypoints) + """;
        let route = L.polyline(waypoints, {color: 'blue', dashArray: '5,5'}).addTo(map);
        waypoints.forEach((wp, i) => {
            L.circleMarker(wp, {radius: 6, color: 'blue'})
                .bindPopup(`WP ${i}`)
                .addTo(map);
        });
        """
        self.map_view.page().runJavaScript(js)
```

### 4.2 Mission Statistics

```
┌─────────────────────────────┐
│ MISSION STATS               │
├─────────────────────────────┤
│ Total Waypoints: 12         │
│ Distance: 5.2 km            │
│ Est. Time: 18 min (5 m/s)  │
│ Current WP: 7 / 12          │
│ Progress: ███░░░░░░ 58%     │
└─────────────────────────────┘
```

## Phase 5: Sensor Fusion (Months 5-7)

### 5.1 Camera Integration

```python
# vision/sensor_fusion.py (NEW)
import cv2
import numpy as np
from scipy.spatial.transform import Rotation

class SensorFusion:
    def __init__(self):
        self.camera_matrix = np.array([
            [1000, 0, 320],
            [0, 1000, 240],
            [0, 0, 1]
        ])  # Example camera calibration
    
    def project_gps_to_image(self, gps_lat, gps_lon, drone_lat, drone_lon, 
                             drone_alt, roll, pitch, yaw):
        """Project ground GPS point onto camera image"""
        # Convert GPS to local NED coordinates
        lat_diff = (gps_lat - drone_lat) * 111000  # meters per degree
        lon_diff = (gps_lon - drone_lon) * 111000 * np.cos(np.radians(drone_lat))
        alt_diff = drone_alt  # Ground is below
        
        ned_point = np.array([lat_diff, lon_diff, alt_diff])
        
        # Apply rotation (drone attitude)
        r = Rotation.from_euler('xyz', [roll, pitch, yaw])
        camera_point = r.apply(ned_point)
        
        # Project to image plane
        image_point = self.camera_matrix @ camera_point
        image_point = image_point[:2] / image_point[2]
        
        return image_point
    
    def overlay_poi(self, frame, points_dict):
        """Overlay POIs on live video"""
        for name, (u, v) in points_dict.items():
            if 0 <= u < frame.shape[1] and 0 <= v < frame.shape[0]:
                cv2.circle(frame, (int(u), int(v)), 5, (0, 255, 0), -1)
                cv2.putText(frame, name, (int(u)+10, int(v)), 
                           cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
        return frame
```

### 5.2 Feature Tracking

```python
# vision/feature_tracker.py (NEW)
class FeatureTracker:
    def __init__(self):
        self.detector = cv2.SIFT_create()
        self.matcher = cv2.BFMatcher()
        self.prev_frame = None
        self.prev_kp = None
        self.prev_des = None
    
    def track(self, frame):
        kp, des = self.detector.detectAndCompute(frame, None)
        
        if self.prev_des is not None:
            matches = self.matcher.knnMatch(self.prev_des, des, k=2)
            # Lowe's ratio test
            good = [m for m, n in matches if m.distance < 0.7 * n.distance]
            
            # Estimate optical flow
            flow_vectors = [
                kp[m.trainIdx].pt - self.prev_kp[m.queryIdx].pt
                for m in good
            ]
        
        self.prev_frame = frame
        self.prev_kp = kp
        self.prev_des = des
        
        return flow_vectors
```

## Phase 6: Advanced Notifications (Months 7-8)

### 6.1 WebSocket Support

```python
# dashboard/websocket_server.py (NEW)
from fastapi import FastAPI, WebSocket
from fastapi.responses import HTMLResponse
import asyncio
import json

app = FastAPI()
connections: Set[WebSocket] = set()

@app.websocket("/ws/telemetry")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    connections.add(websocket)
    
    try:
        while True:
            # Receive command from client
            data = await websocket.receive_text()
            # Broadcast latest telemetry to all clients
            await broadcast({"type": "telemetry", "data": latest_sample})
    except Exception:
        pass
    finally:
        connections.remove(websocket)

async def broadcast(message: dict):
    for connection in connections:
        await connection.send_json(message)

# Then in dashboard: connect to /ws/telemetry for live updates
```

### 6.2 Browser Dashboard

```html
<!-- dashboard/web/index.html (NEW) -->
<!DOCTYPE html>
<html>
<head>
    <title>Drone Telemetry Live</title>
    <link rel="stylesheet" href="style.css">
    <script src="https://cdn.jsdelivr.net/npm/leaflet@1.9/dist/leaflet.js"></script>
</head>
<body>
    <div id="telemetry-cards"></div>
    <div id="map"></div>
    
    <script>
        const ws = new WebSocket('ws://localhost:8000/ws/telemetry');
        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            updateDashboard(data);
        };
    </script>
</body>
</html>
```



