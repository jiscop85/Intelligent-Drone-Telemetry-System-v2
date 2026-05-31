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

