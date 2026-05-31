# Intelligent Drone Telemetry System v2

**Production-grade real-time drone telemetry collection, analysis, and visualization system**

A modular, thread-safe, data-schema driven platform for autonomous drone operations monitoring with support for MAVSDK, MQTT, ROS2, and live video overlay.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Drone / Autopilot                            │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ↓
                    ┌──────────────────────┐
                    │ MAVSDK C++ Collector │ (Thread-safe, 10-20 Hz)
                    │   - Position        │
                    │   - Altitude        │
                    │   - Battery         │
                    │   - IMU + Wind      │
                    └──────────────────────┘
                               │
                ┌──────────────┴──────────────┐
                │                             │
                ↓                             ↓
        ┌──────────────────┐         ┌────────────────┐
        │  Telemetry       │         │   JSON Payload │
        │  Normalizer      │         │  (NED Frame)   │
        └──────────────────┘         └────────────────┘
                │                             │
                └──────────────┬──────────────┘
                               ↓
                        ┌──────────────┐
                        │ MQTT Broker  │ (Mosquitto)
                        │ Topic: drone/│
                        │  telemetry   │
                        └──────────────┘
            ┌──────────┬────────────┬────────────┐
            ↓          ↓            ↓            ↓
        ┌────────┐ ┌────────┐ ┌──────────┐ ┌─────────┐
        │Python  │ │ROS2    │ │OpenCV    │ │ CSV/GeoJSON
        │PyQt6   │ │Bridge  │ │Overlay   │ │ Export
        │Dashboard│ │Node    │ │Viewer    │ │
        └────────┘ └────────┘ └──────────┘ └─────────┘
```

## System Requirements

- **OS**: Linux (Ubuntu 20.04+ recommended) or macOS
- **C++17** compatible compiler
- **Python 3.9+**
- **MQTT Broker**: Mosquitto
- **ROS2**: Humble or newer (optional, for bridge)
- **GPU**: Optional (for advanced analytics)

## Quick Start (5 minutes)

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y \
    build-essential cmake git \
    libmavsdk-dev \
    libmosquitto-dev libmosquittopp-dev \
    nlohmann-json3-dev \
    python3-pip mosquitto

# Install Python dependencies
cd drone_telemetry_system
pip install -r dashboard/requirements.txt
```

### Step 1: Start MQTT Broker

```bash
# Start Mosquitto (ensure it's installed)
mosquitto -c /etc/mosquitto/mosquitto.conf

# Or use Docker
docker run -d --name mosquitto -p 1883:1883 eclipse-mosquitto:latest
```

### Step 2: Build & Run C++ Collector

```bash
mkdir -p build && cd build
cmake ..
make

# Run collector (connects to MAVSDK on localhost:14540)
./cpp_collector/telemetry_collector
```

### Step 3: Launch Python Dashboard

```bash
# In new terminal
cd drone_telemetry_system
python3 dashboard/app.py
```

The PyQt6 dashboard will open showing:
- Live GPS position and track
- Altitude, battery, temperature
- Real-time velocity/wind vectors
- Anomaly detection status
- Export buttons for CSV and GeoJSON

### Step 4: (Optional) ROS2 Bridge

```bash
# Source ROS2 environment
source /opt/ros/humble/setup.bash

# Run bridge
cd drone_telemetry_system
python3 ros2_bridge/bridge_node.py
```

### Step 5: (Optional) Video Overlay

```bash
# In new terminal (requires camera)
python3 drone_telemetry_system/vision/overlay.py
```

## Detailed Setup Guide

### Building C++ Collector

```bash
cd drone_telemetry_system/cpp_collector

# Option 1: CMake (Recommended)
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
make install  # Optional: installs to /usr/local/bin

# Option 2: Quick compile
g++ -std=c++17 -O2 main.cpp -o telemetry_collector \
  $(pkg-config --cflags --libs mavsdk) \
  -lpaho-mqttpp3 -lpaho-mqtt3as
```

### Docker Setup (Recommended for MQTT)

```bash
# Mosquitto MQTT Broker
docker run -d \
  --name drone-mqtt \
  -p 1883:1883 \
  -p 9001:9001 \
  eclipse-mosquitto:latest

# View logs
docker logs drone-mqtt

# Test MQTT
mosquitto_sub -h localhost -t "drone/telemetry"
```

### Python Environment Setup

```bash
# Option 1: Virtual Environment (Recommended)
python3 -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows
pip install -r dashboard/requirements.txt

# Option 2: Conda
conda create -n drone-telemetry python=3.10
conda activate drone-telemetry
pip install -r dashboard/requirements.txt

# Option 3: System-wide
sudo pip install -r dashboard/requirements.txt
```

### ROS2 Setup

```bash
# Install ROS2 (Ubuntu)
curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key | sudo apt-key add -
sudo apt install software-properties-common
sudo add-apt-repository universe
sudo apt update && sudo apt install ros-humble-desktop

# Source ROS2
source /opt/ros/humble/setup.bash

# Build ROS2 package
colcon build --packages-select drone_telemetry_bridge
```

## Running the Full System

### Automated Startup Script (Linux/macOS)

```bash
#!/bin/bash
# Start everything at once

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Starting Drone Telemetry System...${NC}"

# Start MQTT
echo -e "${GREEN}[1/5] Starting MQTT Broker...${NC}"
mosquitto -d -c /etc/mosquitto/mosquitto.conf

sleep 2

# Start C++ Collector
echo -e "${GREEN}[2/5] Starting C++ Collector...${NC}"
cd drone_telemetry_system/cpp_collector
./telemetry_collector &
COLLECTOR_PID=$!

sleep 2

# Start Dashboard
echo -e "${GREEN}[3/5] Starting Python Dashboard...${NC}"
cd ../../
python3 dashboard/app.py &
DASHBOARD_PID=$!

# Start ROS2 Bridge (if ROS2 available)
if command -v ros2 &> /dev/null; then
    echo -e "${GREEN}[4/5] Starting ROS2 Bridge...${NC}"
    source /opt/ros/humble/setup.bash
    python3 ros2_bridge/bridge_node.py &
    ROS_PID=$!
else
    echo -e "${YELLOW}[4/5] ROS2 not found, skipping bridge${NC}"
fi

echo -e "${GREEN}[5/5] System running!${NC}"
echo "Dashboard PID: $DASHBOARD_PID"
echo "Collector PID: $COLLECTOR_PID"
echo ""
echo "To stop: kill $COLLECTOR_PID $DASHBOARD_PID"
```

## Testing & Verification

### Test MQTT Connectivity

```bash
# Subscribe to telemetry
mosquitto_sub -h localhost -t "drone/telemetry" -v

# Should see JSON messages like:
# drone/telemetry {
#   "ts_ms": 1710000000000,
#   "gps": {"lat": 52.52, "lon": 13.405},
#   "altitude_m": {"relative": 48.2, "absolute": 112.4},
#   ...
# }
```

### Test C++ Collector

```bash
# Build and run with verbose output
cd cpp_collector/build
./telemetry_collector 2>&1 | head -20
# Look for: "Connected to MQTT broker"
# Look for: "Waiting for drone..."
```

### Test Python Dashboard

```bash
# Run with debug output
python3 -u dashboard/app.py 2>&1 | head -30
# Should show: "MQTT connected: 0"
```

### Test ROS2 Bridge

```bash
ros2 topic list
ros2 topic echo /drone/telemetry/raw
ros2 topic echo /drone/gps
```

## Configuration

### MQTT Configuration

Edit `/etc/mosquitto/mosquitto.conf`:

```mosquitto
# Listen on all interfaces
listener 1883
protocol mqtt

# WebSocket support (optional, for browser dashboards)
listener 9001
protocol websockets

# Persistence
persistence true
persistence_location /var/lib/mosquitto/

# Log output
log_dest stdout
log_dest topic
log_type all
```

### C++ Collector Configuration

Environment variables:

```bash
# MQTT Connection
export MQTT_BROKER="tcp://localhost:1883"
export MQTT_TOPIC="drone/telemetry"

# MAVSDK Connection
export MAVSDK_URL="udp://:14540"
```

### Dashboard Configuration

In `dashboard/app.py`, modify constants:

```python
BROKER = "localhost"        # MQTT broker hostname
MQTT_PORT = 1883           # MQTT port
TOPIC = "drone/telemetry"  # Subscription topic
```

## Data Schema Reference

All telemetry follows this JSON schema (published every 100ms at 10 Hz):

```json
{
  "ts_ms": 1710000000000,
  "flight_id": "flight_001",
  
  "gps": {
    "lat": 52.5200,
    "lon": 13.4050
  },
  
  "altitude_m": {
    "absolute": 112.4,
    "relative": 48.2
  },
  
  "battery": {
    "voltage_v": 15.8,
    "percent": 87.0
  },
  
  "imu": {
    "ax": 0.02, "ay": -0.01, "az": 9.81,
    "gx": 0.001, "gy": 0.004, "gz": -0.002,
    "temperature_c": 42.5
  },
  
  "velocity_ned": {
    "north_m_s": 3.2,
    "east_m_s": 0.8,
    "down_m_s": -0.4,
    "ground_speed_mps": 3.3
  },
  
  "wind": {
    "north_m_s": 1.1,
    "east_m_s": 0.3,
    "down_m_s": 0.0,
    "speed_mps": 1.14
  },
  
  "state": {
    "armed": true,
    "in_air": true
  },
  
  "quality": {
    "gps_fix": 3,
    "signal_ok": true
  }
}
```

## Module Documentation

### C++ Collector (`cpp_collector/`)

- **Language**: C++17
- **Dependencies**: MAVSDK, MQTT (Paho), nlohmann/json
- **Update Rate**: 10-20 Hz (configurable)
- **Output**: JSON MQTT messages
- **Thread Model**: Multi-threaded with mutex-protected state

```
TelemetryCollector (main thread)
├─ MQTT Publisher Thread (100ms loop)
└─ MAVSDK Callbacks (internal threads)
   ├─ Position callback
   ├─ Altitude callback
   ├─ Battery callback
   ├─ IMU callback
   ├─ Velocity callback
   ├─ Wind callback
   ├─ Armed callback
   └─ In-air callback
```

### Python Dashboard (`dashboard/`)

- **Language**: Python 3.9+
- **Framework**: PyQt6 + pyqtgraph
- **Architecture**: Qt signals/slots + MQTT worker thread
- **Features**:
  - Live status cards (8 fields)
  - Real-time line plots (altitude, battery, speed)
  - Interactive Leaflet map with flight track
  - CSV/GeoJSON export
  - Anomaly detection integration
  - 5000-sample ring buffer

### Analytics Module (`analytics/`)

- **ML Framework**: scikit-learn (IsolationForest)
- **Features**: rel_alt_m, battery_pct, ground_speed_mps, temp_c, wind_speed_mps
- **Training**: `python3 train_model.py flight_data.csv`
- **Scoring**: Live sample scoring with fallback heuristics

### ROS2 Bridge (`ros2_bridge/`)

- **Topics Published**:
  - `/drone/telemetry/raw` (String)
  - `/drone/gps` (NavSatFix)
  - `/drone/velocity` (TwistStamped)
- **Frequency**: Same as MQTT input (10 Hz)
- **Use**: Integrate with other ROS2 nodes

### Vision Module (`vision/`)

- **Framework**: OpenCV 4.5+
- **Input**: Webcam (device 0)
- **Overlay**: Live telemetry labels
- **Fields**: GPS, altitude, battery, temperature, speed
- **Resolution**: Camera native (typically 1080p)

## Performance Metrics

### Latency
- MQTT publish: <10ms
- Dashboard update: 4 FPS (250ms refresh)
- Map refresh: <100ms JavaScript execution

### Resource Usage (typical)
- C++ Collector: ~50 MB RAM, <5% CPU
- Python Dashboard: ~200 MB RAM, 10-20% CPU (rendering)
- ROS2 Bridge: ~100 MB RAM, <5% CPU

### Storage
- CSV export: ~200 bytes/sample (5000 samples = 1 MB)
- GeoJSON export: ~400 bytes/sample

## Troubleshooting

### "MQTT connection refused"
```bash
# Check MQTT is running
mosquitto_pub -h localhost -t test -m hello
# If fails, start MQTT:
mosquitto -d
```

### "No drone found"
```bash
# Check MAVSDK UDP connection
netstat -an | grep 14540
# Start PX4 SITL or real autopilot on this port
```

### "Dashboard shows '--' for all values"
```bash
# Check MQTT is receiving data
mosquitto_sub -h localhost -t "drone/telemetry"
# Check Python subprocess in dashboard output
```

### "AttributeError: PyQt6 not installed"
```bash
pip install PyQt6 PyQt6-WebEngine pyqtgraph
```
