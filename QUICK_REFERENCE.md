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

