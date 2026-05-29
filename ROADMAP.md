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
    