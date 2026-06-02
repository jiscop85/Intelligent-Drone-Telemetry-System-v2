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


log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        DISTRO=$(lsb_release -si 2>/dev/null || echo "Unknown")
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        log_error "Unsupported OS: $OSTYPE"
        exit 1
    fi
    
    log_info "Detected: $OS ($DISTRO)"
}

# Install dependencies
install_deps() {
    log_info "Installing dependencies..."
    
    if [ "$OS" == "linux" ]; then
        if command -v apt-get &> /dev/null; then
            log_info "Using apt package manager"
            sudo apt-get update
            sudo apt-get install -y \
                build-essential cmake git \
                libmavsdk-dev \
                libmosquitto-dev libmosquittopp-dev \
                nlohmann-json3-dev \
                pkg-config
        elif command -v dnf &> /dev/null; then
            log_info "Using dnf package manager"
            sudo dnf install -y \
                gcc-c++ cmake \
                mavsdk-devel \
                mosquitto-devel \
                nlohmann-json-devel \
                pkg-config
        else
            log_error "Unsupported package manager"
            exit 1
        fi
    elif [ "$OS" == "macos" ]; then
        log_info "Using Homebrew"
        if ! command -v brew &> /dev/null; then
            log_error "Homebrew not found. Install from https://brew.sh"
            exit 1
        fi
        
        brew install mavsdk mosquitto nlohmann-json cmake pkg-config
    fi
    
    log_success "Dependencies installed"
}

# Build with CMake
build_cmake() {
    log_info "Building with CMake..."
    
    cd "$COLLECTOR_DIR"
    
    if [ -d "$BUILD_DIR" ]; then
        log_info "Cleaning previous build..."
        rm -rf "$BUILD_DIR"
    fi
    
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    log_info "Running cmake..."
    cmake -DCMAKE_BUILD_TYPE=Release ..
    
    log_info "Compiling (using $(nproc) cores)..."
    make -j$(nproc)
    
    if [ -f "./telemetry_collector" ]; then
        log_success "Build successful!"
        log_info "Binary: $BUILD_DIR/telemetry_collector"
