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
