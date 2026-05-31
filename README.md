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
