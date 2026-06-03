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
