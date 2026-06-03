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
 
