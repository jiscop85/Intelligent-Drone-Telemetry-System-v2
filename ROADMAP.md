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

