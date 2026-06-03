#!/bin/bash
# First-time setup script for Intelligent Drone Telemetry System
# Sets up the entire environment

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

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

# Print header
print_header() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║   Intelligent Drone Telemetry System - Setup           ║"
    echo "║   Version 2.0                                          ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check Python version
check_python() {
    log_info "Checking Python version..."
    
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found. Install Python 3.9+"
        exit 1
    fi
    
    VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    MAJOR=$(echo $VERSION | cut -d. -f1)
    MINOR=$(echo $VERSION | cut -d. -f2)
    
    if [ "$MAJOR" -lt 3 ] || ([ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 9 ]); then
        log_error "Python 3.9+ required, found $VERSION"
        exit 1
    fi
    
    log_success "Python $VERSION found"
}

# Create directory structure
setup_directories() {
    log_info "Setting up directories..."
    
    mkdir -p "$PROJECT_DIR"/{logs,data/{db,models,flights},scripts,config}
    
    log_success "Directories created"
}

# Python virtual environment
setup_venv() {
    log_info "Setting up Python virtual environment..."
    
    VENV_DIR="${PROJECT_DIR}/venv"
    
    if [ -d "$VENV_DIR" ]; then
        log_warn "Virtual environment already exists"
        read -p "Recreate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$VENV_DIR"
        else
            return
        fi
    fi
    
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    
    log_info "Upgrading pip..."
    pip install --upgrade pip setuptools wheel
    
    log_info "Installing Python dependencies..."
    cd "$PROJECT_DIR/drone_telemetry_system"
    pip install -r dashboard/requirements.txt
    
    log_success "Python environment ready"
    log_info "Activate with: source $VENV_DIR/bin/activate"
}

# C++ build setup
setup_cpp() {
    log_info "Setting up C++ build environment..."
    
    if ! command -v cmake &> /dev/null; then
        log_warn "CMake not found"
        read -p "Install build tools? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            bash "$PROJECT_DIR/scripts/build_cpp.sh" 3
        fi
    else
        log_success "CMake found"
    fi
    
    log_info "To build collector: bash scripts/build_cpp.sh"
}

# MQTT setup
setup_mqtt() {
    log_info "Checking MQTT setup..."
    
    if command -v mosquitto &> /dev/null; then
        log_success "Mosquitto found"
    else
        log_warn "Mosquitto not found"
        read -p "Use Docker for MQTT? (Y/n): " -n 1 -r
        echo
        
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            if command -v docker &> /dev/null; then
                log_info "Starting MQTT with Docker..."
                docker run -d --name drone-mqtt -p 1883:1883 eclipse-mosquitto:latest
                log_success "MQTT running in Docker"
            else
                log_error "Docker not found"
                log_info "Install from: https://docs.docker.com/install"
            fi
        else
            log_info "To install Mosquitto:"
            if command -v apt-get &> /dev/null; then
                echo "  sudo apt-get install mosquitto"
            elif command -v brew &> /dev/null; then
                echo "  brew install mosquitto"
            fi
        fi
    fi
}

# Configuration files
setup_config() {
    log_info "Setting up configuration files..."
    
    # Copy example configs if they don't exist
    if [ ! -f "$PROJECT_DIR/config/mosquitto.conf" ]; then
        cat > "$PROJECT_DIR/config/mosquitto.conf" << 'EOF'
# Mosquitto configuration for Drone Telemetry System
listener 1883
protocol mqtt

listener 9001
protocol websockets

persistence true
persistence_location /var/lib/mosquitto/

log_dest stdout
log_dest topic
log_type all
EOF
        log_success "Created mosquitto.conf"
    fi
    
    # Create .env file for configuration
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        cat > "$PROJECT_DIR/.env" << 'EOF'
# Drone Telemetry System Configuration

# MQTT Configuration
MQTT_HOST=localhost
MQTT_PORT=1883
MQTT_TOPIC=drone/telemetry

# MAVSDK Connection
MAVSDK_URL=udp://:14540

# Dashboard
DASHBOARD_PORT=5000
DASHBOARD_HOST=localhost

# Database
DATABASE_URL=sqlite:///data/db/flights.db

# Logging
LOG_LEVEL=INFO
EOF
        log_success "Created .env"
    fi
}

# Create systemd service (optional)
setup_systemd() {
    log_info "Systemd service setup..."
    
    read -p "Create systemd service files? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Collector service
        sudo tee /etc/systemd/system/drone-collector.service > /dev/null << EOF
[Unit]
Description=Drone Telemetry Collector
After=mosquitto.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/drone_telemetry_system/cpp_collector/build/telemetry_collector
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        # Dashboard service
        sudo tee /etc/systemd/system/drone-dashboard.service > /dev/null << EOF
[Unit]
Description=Drone Telemetry Dashboard
After=mosquitto.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$PROJECT_DIR/venv/bin"
ExecStart=$PROJECT_DIR/venv/bin/python3 drone_telemetry_system/dashboard/app.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        sudo systemctl daemon-reload
        log_success "Systemd services created"
        log_info "Start with: sudo systemctl start drone-collector drone-dashboard"
    fi
}

# Test installation
test_installation() {
    log_info "Testing installation..."
    
    # Test Python imports
    python3 << 'EOF'
try:
    import PyQt6
    import paho.mqtt.client
    import pyqtgraph
    import pandas
    import sklearn
    import numpy
    print("✓ All Python dependencies available")
except ImportError as e:
    print(f"✗ Missing: {e}")
    exit(1)
EOF
    
    # Test MQTT
    if command -v mosquitto_pub &> /dev/null; then
        if mosquitto_pub -h localhost -t test -m hello 2>/dev/null; then
            log_success "MQTT connection OK"
        else
            log_warn "MQTT not responding - start with 'mosquitto -d'"
        fi
    fi
    
    log_success "Installation test passed"
}
# Summary
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Setup Complete!                                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Quick Start:${NC}"
    echo "  1. Activate Python environment:"
    echo "     source $PROJECT_DIR/venv/bin/activate"
    echo ""
    echo "  2. Build C++ collector:"
    echo "     bash $PROJECT_DIR/scripts/build_cpp.sh"
    echo ""
    echo "  3. Start everything:"
    echo "     bash $PROJECT_DIR/scripts/start_all.sh --docker"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  README:   $PROJECT_DIR/README.md"
    echo "  Roadmap:  $PROJECT_DIR/ROADMAP.md"
    echo ""
    echo -e "${BLUE}Logs:${NC}"
    echo "  $PROJECT_DIR/logs/"
    echo ""
}

# Main
main() {
    print_header
    
    echo "This script will set up the Drone Telemetry System for development."
    echo ""
    read -p "Continue? (Y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        exit 0
    fi
    
    check_python
    setup_directories
    setup_venv
    setup_cpp
    setup_mqtt
    setup_config
    test_installation
    
    read -p "Create systemd services? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_systemd
    fi
    
    print_summary
}

# Help
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    cat << EOF
Usage: $0 [OPTIONS]

Setup Intelligent Drone Telemetry System

Options:
  --help              Show this help message
  --uninstall         Remove virtual environment and build artifacts
  --check             Check installation only

EOF
    exit 0
fi

# Uninstall
if [ "$1" == "--uninstall" ]; then
    log_warn "Uninstalling..."
    rm -rf "$PROJECT_DIR/venv"
    rm -rf "$PROJECT_DIR/drone_telemetry_system/cpp_collector/build"
    rm -rf "$PROJECT_DIR/logs/*"
    log_success "Uninstalled"
    exit 0
fi

# Check only
if [ "$1" == "--check" ]; then
    log_info "Checking installation..."
    test_installation
    exit 0
fi

main


