#!/bin/bash
# Start all components of the Drone Telemetry System
# Usage: ./scripts/start_all.sh [--docker] [--ros2]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${PROJECT_DIR}/logs"
mkdir -p "$LOG_DIR"

# Configuration
MQTT_HOST="${MQTT_HOST:-localhost}"
MQTT_PORT="${MQTT_PORT:-1883}"
MAVSDK_URL="${MAVSDK_URL:-udp://:14540}"
DASHBOARD_PORT="${DASHBOARD_PORT:-5000}"
USE_DOCKER="${1:-}"
USE_ROS2="${2:-}"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

cleanup() {
    log_warn "Shutting down..."
    
    # Kill all background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    if [ ! -z "$MQTT_CONTAINER_ID" ]; then
        log_info "Stopping MQTT container..."
        docker stop "$MQTT_CONTAINER_ID" 2>/dev/null || true
    fi
    
    log_success "Shutdown complete"
}

trap cleanup EXIT

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check C++ collector
    if [ ! -f "${PROJECT_DIR}/drone_telemetry_system/cpp_collector/build/telemetry_collector" ]; then
        log_warn "C++ collector not built. Run: ./scripts/build_cpp.sh"
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found"
        exit 1
    fi
    
    # Check MQTT
    if [ "$USE_DOCKER" != "--docker" ]; then
        if ! command -v mosquitto &> /dev/null; then
            log_warn "Mosquitto not found. Use --docker flag or install with: sudo apt-get install mosquitto"
        fi
    fi
    
    log_success "Dependency check complete"
}

# Start MQTT Broker
start_mqtt() {
    log_info "Starting MQTT Broker..."
    
    if [ "$USE_DOCKER" == "--docker" ]; then
        log_info "Using Docker for MQTT"
        MQTT_CONTAINER_ID=$(docker run -d \
            --name drone-mqtt-$(date +%s) \
            -p "$MQTT_PORT:1883" \
            eclipse-mosquitto:latest)
        log_success "MQTT running in Docker (ID: ${MQTT_CONTAINER_ID:0:12})"
    else
 
