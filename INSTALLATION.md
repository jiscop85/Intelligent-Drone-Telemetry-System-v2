# System Requirements & Installation Guide

## Minimum Hardware Requirements

### Development/Testing
- **CPU**: Intel i5 / AMD Ryzen 5 (2 cores)
- **RAM**: 4 GB
- **Storage**: 500 MB (code + dependencies)
- **Network**: 100 Mbps LAN (for MQTT)

### Single Drone Operation
- **CPU**: Intel i7 / AMD Ryzen 7 (4 cores)
- **RAM**: 8 GB
- **Storage**: 1 GB (code + small databases)
- **Network**: Gigabit LAN

### Multi-Drone Operation (Phase 1-2)
- **CPU**: Server CPU (8+ cores)
- **RAM**: 16-32 GB
- **Storage**: 50-100 GB (flight history, ML models)
- **Network**: Gigabit + redundancy

### Production Enterprise (Phase 3+)
- **CPU**: Cloud VM (16+ vCPU)
- **RAM**: 32-64 GB
- **Storage**: 500+ GB (long-term archive)
- **Network**: Cloud networking + CDN for web

## Operating System Requirements

### Supported
- **Linux**: Ubuntu 20.04 LTS, 22.04 LTS (recommended)
- **Linux**: Debian 11, 12
- **Linux**: Fedora 38+
- **macOS**: 11.x, 12.x, 13.x
- **Windows**: WSL2 (Windows Subsystem for Linux)

### Not Supported
- **Windows (native)**: Use WSL2 or Docker
- **iOS/Android**: Use Web Dashboard (Phase 3)
- **Raspberry Pi**: Possible but requires optimization (Pi 4 minimum)

## Software Dependencies

### Essential
| Component | Version | Purpose |
|-----------|---------|---------|
| Python | 3.9+ | Dashboard, analytics |
| C++ Compiler | C++17 | Collector compilation |
| CMake | 3.10+ | Build system |
| MAVSDK | Latest | Autopilot communication |
| MQTT Broker | Any | Message distribution |
| Git | Latest | Version control |

### Dashboard (Python)
```
PyQt6==6.6.0                # Desktop UI framework
PyQt6-WebEngine==6.6.0      # Map rendering
pyqtgraph==0.13.3           # Real-time charts
paho-mqtt==1.6.1            # MQTT client
pandas==2.0.3               # Data analysis
numpy==1.24.3               # Numerical computing
scikit-learn==1.3.1         # ML (anomaly detection)
joblib==1.3.2               # Model serialization
```

### C++ Collector
```
MAVSDK (libmavsdk-dev)      # Autopilot SDK
Paho MQTT C++ (libpaho-mqttpp3-dev)  # MQTT client
nlohmann/json (nlohmann-json3-dev)   # JSON serialization
```

### Optional (Phase 1+)
- **SQLAlchemy**: Database ORM
- **InfluxDB**: Time-series storage
- **Grafana**: Visualization
- **PostgreSQL**: Production database

## Installation Steps

### 1. Prerequisites (Ubuntu 22.04)

```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential cmake git \
    python3-dev python3-pip python3-venv \
    libmavsdk-dev \
    libmosquitto-dev libmosquittopp-dev \
    nlohmann-json3-dev \
    pkg-config
```

### "PyQt6 import error"
```bash
pip install --upgrade PyQt6 PyQt6-WebEngine
```

### "Mosquitto won't start"
```bash
# Check if already running
pgrep mosquitto

# If running, kill it
pkill mosquitto

# Try system service
sudo systemctl start mosquitto

# Check status
mosquitto_pub -h localhost -t test -m hello
```

### "Permission denied on MQTT"
```bash
# Check MQTT config
cat /etc/mosquitto/mosquitto.conf | grep allow_anonymous

# Set to true for development
sudo sed -i 's/^#allow_anonymous true/allow_anonymous true/' /etc/mosquitto/mosquitto.conf
sudo systemctl restart mosquitto
```

### "C++ collector can't find MAVSDK"
```bash
# Check CMakeLists.txt paths
cmake --trace 2>&1 | grep MAVSDK

# Manually specify
cmake -DCMAKE_PREFIX_PATH=/usr/local ..
```

## Performance Tuning

### For High-Frequency Telemetry

**C++ Collector**:
```cpp
// main.cpp
telemetry_->set_rate_imu(100.0);  // 100 Hz instead of 20
telemetry_->set_rate_position(50.0);  // 50 Hz
```

**MQTT Broker**:
```conf
# mosquitto.conf
thread_count 8
max_inflight_messages 100
```

### For Long-Term Storage (Phase 1)

**SQLite Optimization**:
```python
# telemetry_store.py
db.execute("CREATE INDEX idx_flight_id ON telemetry(flight_id)")
db.execute("CREATE INDEX idx_timestamp ON telemetry(ts_ms)")
```

### For Large Deployments

Use **InfluxDB** + **Grafana**:
```bash
docker run -d -p 8086:8086 influxdb:latest
docker run -d -p 3000:3000 grafana/grafana:latest
```

## Backup & Recovery

### Backup Configuration

```bash
# Backup database
cp data/db/flights.db data/db/flights.db.backup

# Backup models
tar -czf data/models/backup.tar.gz data/models/

# Backup dashboard config
cp dashboard/app.py dashboard/app.py.backup
```

### Recovery

```bash
# Restore from backup
cp data/db/flights.db.backup data/db/flights.db

# Restore models
tar -xzf data/models/backup.tar.gz
```

## Updates & Upgrades

### Minor Version (2.0.x)
```bash
git pull origin main
pip install -r drone_telemetry_system/dashboard/requirements.txt --upgrade
bash scripts/build_cpp.sh 1
```

### Major Version (3.0)
```bash
# Full reinstall recommended
bash scripts/setup.sh --uninstall
bash scripts/setup.sh
```

## Support & Resources

- **Issues**: GitHub Issues
- **Documentation**: See README.md, ARCHITECTURE.md, ROADMAP.md
- **MAVSDK Docs**: https://mavsdk.mavlink.io/
- **MQTT Specs**: https://mqtt.org/
- **ROS2 Docs**: https://docs.ros.org/
- **PyQt6 Guide**: https://www.riverbankcomputing.com/static/Docs/PyQt6/

---

**Last Updated**: 2026-05-29  
**Status**: Production Ready for MVP v2
