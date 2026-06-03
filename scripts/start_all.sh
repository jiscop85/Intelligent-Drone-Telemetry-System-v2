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
        # Check if already running
        if pgrep -x "mosquitto" > /dev/null; then
            log_success "MQTT already running"
        else
            log_info "Starting Mosquitto..."
            mosquitto -d -c /etc/mosquitto/mosquitto.conf 2>/dev/null || \
                mosquitto -d 2>/dev/null || {
                log_error "Failed to start Mosquitto"
                exit 1
            }
            log_success "MQTT started (PID: $!)"
        fi
    fi
    
    # Wait for MQTT to be ready
    sleep 2
    if mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -t "test" -m "hello" 2>/dev/null; then
        log_success "MQTT is responsive"
    else
        log_error "MQTT not responding"
        exit 1
    fi
}

# Start C++ Collector
start_collector() {
    log_info "Starting C++ Telemetry Collector..."
    
    COLLECTOR_BIN="${PROJECT_DIR}/drone_telemetry_system/cpp_collector/build/telemetry_collector"
    
    if [ ! -f "$COLLECTOR_BIN" ]; then
        log_error "Collector not built. Run: cd drone_telemetry_system/cpp_collector && mkdir build && cd build && cmake .. && make"
        return 1
    fi
    
    export MQTT_BROKER="tcp://${MQTT_HOST}:${MQTT_PORT}"
    export MAVSDK_URL="$MAVSDK_URL"
    
    "$COLLECTOR_BIN" >> "$LOG_DIR/collector.log" 2>&1 &
    COLLECTOR_PID=$!
    
    log_success "Collector started (PID: $COLLECTOR_PID)"
    
    # Check if collector is still running after 2 seconds
    sleep 2
    if ! kill -0 $COLLECTOR_PID 2>/dev/null; then
        log_error "Collector crashed. Check logs:"
        cat "$LOG_DIR/collector.log"
        exit 1
    fi
}

# Start Python Dashboard
start_dashboard() {
    log_info "Starting Python Dashboard..."
    
    cd "$PROJECT_DIR/drone_telemetry_system"
    
    # Check Python dependencies
    if ! python3 -c "import PyQt6" 2>/dev/null; then
        log_warn "PyQt6 not installed. Installing..."
        pip install -r dashboard/requirements.txt
    fi
    
    python3 dashboard/app.py >> "$LOG_DIR/dashboard.log" 2>&1 &
    DASHBOARD_PID=$!
    
    log_success "Dashboard started (PID: $DASHBOARD_PID)"
    log_info "Dashboard URL: http://localhost:$DASHBOARD_PORT"
}
# Start ROS2 Bridge
start_ros2_bridge() {
    if [ "$USE_ROS2" != "--ros2" ]; then
        log_warn "ROS2 bridge disabled. Use --ros2 flag to enable"
        return
    fi
    
    log_info "Starting ROS2 Bridge..."
    
    # Check ROS2 environment
    if [ -z "$ROS_DISTRO" ]; then
        log_warn "ROS2 not sourced. Attempting to source..."
        if [ -f "/opt/ros/humble/setup.bash" ]; then
            source /opt/ros/humble/setup.bash
        else
            log_warn "Could not find ROS2. Skipping bridge"
            return
        fi
    fi
    
    cd "$PROJECT_DIR/drone_telemetry_system"
    python3 ros2_bridge/bridge_node.py >> "$LOG_DIR/ros2_bridge.log" 2>&1 &
    ROS2_PID=$!
    
    log_success "ROS2 Bridge started (PID: $ROS2_PID)"
}

# Main execution
main() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║   Intelligent Drone Telemetry System v2                  ║"
    echo "║         Starting All Components                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_dependencies
    echo ""
    
    log_info "Configuration:"
    echo "  MQTT Host:      $MQTT_HOST:$MQTT_PORT"
    echo "  MAVSDK URL:     $MAVSDK_URL"
    echo "  Log Directory:  $LOG_DIR"
    echo ""
    
    start_mqtt
    sleep 1
    
    start_collector
    sleep 1
    
    start_dashboard
    
    if [ "$USE_ROS2" == "--ros2" ]; then
        sleep 1
        start_ros2_bridge
    fi
    
    echo ""
    log_success "All components started!"
    echo ""
    echo -e "${GREEN}System Status:${NC}"
    echo "  MQTT Broker:       http://$MQTT_HOST:$MQTT_PORT"
    echo "  C++ Collector:     Running (checking MAVSDK on $MAVSDK_URL)"
    echo "  Dashboard:         http://localhost:$DASHBOARD_PORT (PyQt6 window)"
    if [ "$USE_ROS2" == "--ros2" ]; then
        echo "  ROS2 Bridge:       Running"
        echo "    - /drone/telemetry/raw"
        echo "    - /drone/gps"
        echo "    - /drone/velocity"
    fi
    echo ""
    echo -e "${YELLOW}Logs:${NC}"
    echo "  tail -f $LOG_DIR/collector.log"
    echo "  tail -f $LOG_DIR/dashboard.log"
    if [ "$USE_ROS2" == "--ros2" ]; then
        echo "  tail -f $LOG_DIR/ros2_bridge.log"
    fi
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to shutdown...${NC}"
    
    # Wait for processes
    wait
}

# Show usage
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --docker    Use Docker for MQTT instead of system Mosquitto
  --ros2      Enable ROS2 bridge
  --help      Show this help message

Environment Variables:
  MQTT_HOST       MQTT broker hostname (default: localhost)
  MQTT_PORT       MQTT broker port (default: 1883)
  MAVSDK_URL      MAVSDK connection URL (default: udp://:14540)

Examples:
  $0                          # Start with system Mosquitto
  $0 --docker                 # Start with Docker MQTT
  $0 --docker --ros2          # Start with Docker MQTT and ROS2 bridge

EOF
    exit 0
fi

main


