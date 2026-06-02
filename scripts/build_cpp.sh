#!/bin/bash
# Build C++ Telemetry Collector
# Handles MAVSDK, MQTT, and JSON dependencies

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COLLECTOR_DIR="${PROJECT_DIR}/drone_telemetry_system/cpp_collector"
BUILD_DIR="${COLLECTOR_DIR}/build"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
