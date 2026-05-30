# Quick Reference Guide

A cheat sheet for common operations, debugging, and configuration.

## 🚀 Quick Start (5 minutes)

```bash
# 1. Clone and setup
git clone <repo>
cd drone-telemetry
bash scripts/setup.sh

# 2. Start MQTT (Docker)
docker run -d -p 1883:1883 eclipse-mosquitto

# 3. Build C++ collector
bash scripts/build_cpp.sh 1

# 4. Start everything
bash scripts/start_all.sh

# 5. View dashboard
# Window opens automatically at localhost:5000
```

## 📁 Project Structure at a Glance

```
drone-telemetry/
├── cpp_collector/           # C++ MAVSDK → MQTT bridge
│   ├── main.cpp            # Entry point
│   ├── telemetry_state.hpp # Data structure
│   └── CMakeLists.txt      # Build config
├── dashboard/              # PyQt6 desktop UI
│   ├── app.py             # Main application
│   ├── telemetry_store.py # In-memory storage
│   └── widgets.py         # UI components
├── analytics/              # ML anomaly detection
│   ├── anomaly_detector.py # Model scoring
│   └── train_model.py     # Training CLI
├── ros2_bridge/            # ROS2 integration
├── vision/                 # OpenCV overlay
├── data/                   # Storage (flights, models, exports)
├── config/                 # Configuration files
├── scripts/                # Automation (setup, build, start)
├── README.md              # Main documentation
├── ARCHITECTURE.md        # Deep technical docs
├── ROADMAP.md            # 7-phase roadmap
├── INSTALLING.md         # Setup guide
├── CONTRIBUTING.md       # Development guide
└── docker-compose.yml    # Infrastructure

```

## 🔧 Common Commands

### Development & Testing

```bash
# Setup environment
bash scripts/setup.sh

# Build C++ collector
bash scripts/build_cpp.sh 1

# Run tests
pytest tests/ -v
pytest tests/unit/test_telemetry_state.py::test_to_json

# Check code style
black drone_telemetry_system/
flake8 drone_telemetry_system/
mypy drone_telemetry_system/
```

### Running the System

```bash
# Full system with Docker MQTT
bash scripts/start_all.sh --docker

# Collector + ROS2 bridge
bash scripts/start_all.sh --ros2

# Just MQTT broker
docker-compose up mosquitto

# Just collector
./build/telemetry_collector

# Just dashboard
source venv/bin/activate
python3 drone_telemetry_system/dashboard/app.py

# Just ROS2 bridge
source /opt/ros/humble/setup.bash
ros2 run drone_telemetry_system ros2_bridge
```

```

## 🔌 Configuration

### Environment Variables (.env)

```bash
# Critical ones
MQTT_HOST=localhost
MQTT_PORT=1883
MAVSDK_URL=udp://:14540

# Tuning
COLLECTOR_INTERVAL_MS=100
DASHBOARD_BUFFER_SIZE=5000
ANOMALY_CONTAMINATION=0.02

# Copy template
cp config/.env.template config/.env
# Then edit as needed
```

### MQTT Topics

```
drone/telemetry          → JSON messages (10 Hz, QoS 1)
drone/gps               → GPS only (ROS2 bridge output)
drone/velocity          → Velocity only (ROS2 bridge output)
drone/telemetry/raw     → String format (ROS2 bridge output)
```

### ROS2 Topics (with bridge)

```
/drone/telemetry/raw    (std_msgs/String) - full JSON
/drone/gps              (sensor_msgs/NavSatFix) - lat/lon/alt
/drone/velocity         (geometry_msgs/TwistStamped) - NED velocities
```

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| "MQTT connection refused" | Check if mosquitto is running: `systemctl status mosquitto` or `docker ps` |
| "MAVSDK connection failed" | Verify PX4 SITL running on UDP 14540 or real drone connected |
| "Dashboard won't start" | Check Python version `python3 --version` (needs 3.9+) and deps `pip list` |
| "C++ compiler not found" | Install: `sudo apt-get install build-essential` |
| "PyQt6 import error" | Reinstall: `pip install --upgrade PyQt6 PyQt6-WebEngine` |
| "No telemetry messages" | Check dashboard MQTT worker thread - see `logs/collector.log` |
| "High CPU usage" | Reduce buffer size or chart update rate in `config/.env` |
| "Out of memory" | Reduce `DASHBOARD_BUFFER_SIZE` or enable SQLite storage (Phase 1) |

## 📈 Performance Tuning

### For Higher Frequency (20+ Hz)

```cpp
// cpp_collector/main.cpp
telemetry_->set_rate_imu(100.0);
telemetry_->set_rate_position(50.0);

// config/.env
COLLECTOR_INTERVAL_MS=50  # 50ms = 20 Hz
```

### For Long Flights (4+ hours)

```bash
# config/.env
DASHBOARD_BUFFER_SIZE=50000  # ~1.4 hours at 10 Hz

# Enable SQLite (Phase 1)
DB_SQLITE_PATH=data/db/flights.db
```

### For Multi-Drone

```bash
# Each drone gets unique flight_id
FLIGHT_ID=drone-001-2026-05-29-14-30-00
FLIGHT_ID=drone-002-2026-05-29-14-30-00

# Shared MQTT broker
MQTT_HOST=192.168.1.100  # Central server
MQTT_TOPIC=drone/{flight_id}/telemetry  # One topic per drone
```

## 🎯 Typical Workflows

### Starting a Flight Session

```bash
# 1. Ensure prerequisites
docker-compose up -d mosquitto
source venv/bin/activate

# 2. Generate flight ID
export FLIGHT_ID=$(date +%Y-%m-%d-%H-%M-%S)
echo "Flight: $FLIGHT_ID"

# 3. Start system
bash scripts/start_all.sh --docker

# 4. Watch for data
mosquitto_sub -t "drone/telemetry" | head -5

# 5. Dashboard opens automatically
# Record video/screenshots as needed
```

### Exporting Flight Data

```python
# In dashboard: File → Export CSV/GeoJSON
# Or programmatic:

from dashboard.telemetry_store import TelemetryStore
store = TelemetryStore.load_from_file("data/exports/flight_2026-05-29-14-30-00.pkl")
store.to_csv("flight_data.csv")
store.to_geojson("flight_track.geojson")
```

### Training Anomaly Model

```bash
# Collect good flight data first
python3 drone_telemetry_system/analytics/train_model.py \
  data/exports/good_flights.csv \
  data/models/detector_v2.pkl \
  --contamination 0.02
```

### Running ROS2 Integration

```bash
# Terminal 1: Start MQTT
docker-compose up mosquitto

# Terminal 2: Start collector
./scripts/build_cpp.sh 1
./build/telemetry_collector

# Terminal 3: Source ROS2 and run bridge
source /opt/ros/humble/setup.bash
ros2 run drone_telemetry_system ros2_bridge

# Terminal 4: Subscribe to ROS2 topics
source /opt/ros/humble/setup.bash
ros2 topic echo /drone/gps
```

## 📚 Key Files to Know

| File | Purpose |
|------|---------|
| `README.md` | Start here - overview and 5-min quick start |
| `ARCHITECTURE.md` | Deep dive - thread models, performance, scalability |
| `ROADMAP.md` | Future features - 7 phases with code examples |
| `INSTALLATION.md` | System requirements and setup |
| `CONTRIBUTING.md` | How to contribute code |
| `cpp_collector/main.cpp` | Where telemetry is collected |
| `dashboard/app.py` | Main UI application |
| `analytics/anomaly_detector.py` | ML anomaly detection |
| `config/.env` | Runtime configuration |
| `docker-compose.yml` | Service definitions |

## 🆘 Getting Help

```
Need...                    Go to...
─────────────────────────────────────
Quick start               README.md, Quick Start section
Setup help               INSTALLATION.md
Architecture Q           ARCHITECTURE.md
Development guide        CONTRIBUTING.md
Bug report               GitHub Issues
Feature request          GitHub Discussions
MQTT trouble             Check mosquitto logs
C++ compilation fail     Check CMakeLists.txt, INSTALLATION.md
```

## ✅ Checklist for New Contributors

- [ ] Fork and clone repo
- [ ] Run `bash scripts/setup.sh`
- [ ] Read README.md and ARCHITECTURE.md
- [ ] Create feature branch: `git checkout -b feature/name`
- [ ] Make changes with clear commits
- [ ] Run tests: `pytest tests/ -v`
- [ ] Check style: `black` and `flake8`
- [ ] Create PR with detailed description
- [ ] Respond to code review feedback

---

**Last Updated**: 2026-05-29  
**For Troubleshooting**: See INSTALLATION.md or open GitHub Issue
