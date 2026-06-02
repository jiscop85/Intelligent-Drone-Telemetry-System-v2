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
        
        # Show size
        SIZE=$(du -h ./telemetry_collector | cut -f1)
        log_info "Binary size: $SIZE"
        
        return 0
    else
        log_error "Build failed - binary not found"
        return 1
    fi
}

# Quick build (no CMake, direct compilation)
build_quick() {
    log_info "Quick build (direct compilation)..."
    
    cd "$COLLECTOR_DIR"
    
    CFLAGS="-std=c++17 -O2 -Wall -Wextra"
    LIBS="-lpaho-mqttpp3 -lpaho-mqtt3as"
    PKG_LIBS=$(pkg-config --cflags --libs mavsdk 2>/dev/null || echo "-lmavsdk")
    
    g++ $CFLAGS main.cpp -o telemetry_collector $PKG_LIBS $LIBS
    
    if [ -f "./telemetry_collector" ]; then
        log_success "Build successful!"
        log_info "Binary: $COLLECTOR_DIR/telemetry_collector"
        return 0
    else
        log_error "Build failed"
        return 1
    fi
}

# Run tests
run_tests() {
    log_info "Running basic tests..."
    
    # Check if binary exists
    if [ ! -f "$BUILD_DIR/telemetry_collector" ]; then
        log_error "Binary not found"
        return 1
    fi
    
    # Check dependencies at runtime
    log_info "Checking library dependencies..."
    ldd "$BUILD_DIR/telemetry_collector" 2>/dev/null | grep -E "mavsdk|mqtt|json" || {
        log_error "Missing dependencies"
        return 1
    }
    
    log_success "All tests passed"
}

# Main
main() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   C++ Telemetry Collector - Build Script   ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    detect_os
    
    # Ask for option
    if [ -z "$1" ]; then
        echo "Build options:"
        echo "  1) Full CMake build (recommended)"
        echo "  2) Quick direct compile"
        echo "  3) Install dependencies only"
        echo "  4) Exit"
        echo ""
        read -p "Select option (1-4): " OPTION
    else
        OPTION=$1
    fi
    
    case $OPTION in
        1)
            install_deps
            build_cmake
            run_tests
            ;;
        2)
            install_deps
            build_quick
            run_tests
            ;;
        3)
            install_deps
            ;;
        4)
            exit 0
            ;;
        *)
            log_error "Invalid option"
            exit 1
            ;;
    esac
    
    echo ""
    log_success "Build complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Start MQTT: mosquitto -d"
    echo "  2. Run collector: $BUILD_DIR/telemetry_collector"
    echo "  3. Run dashboard: python3 dashboard/app.py"
}

# Help
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    cat << EOF
Usage: $0 [OPTION]

Options:
  1             CMake build (default, recommended)
  2             Quick compile (direct g++)
  3             Install dependencies only
  4             Exit
  --help        Show this help

Examples:
  $0            # Interactive menu
  $0 1          # CMake build
  $0 2          # Quick build

EOF
    exit 0
fi

main
