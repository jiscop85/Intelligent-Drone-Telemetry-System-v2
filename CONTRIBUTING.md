# Contributing Guide

Welcome to the Intelligent Drone Telemetry System v2! This guide will help you contribute effectively to the project.

## Code of Conduct

Be respectful, inclusive, and professional. We're all learning and working toward a shared goal.

## Development Setup

### 1. Fork & Clone

```bash
# Fork on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/drone-telemetry.git
cd drone-telemetry
git remote add upstream https://github.com/ORIGINAL_OWNER/drone-telemetry.git
```

### 2. Create Development Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 3. Set Up Development Environment

```bash
# Run setup script
bash scripts/setup.sh

# Activate virtual environment
source venv/bin/activate  # Linux/macOS
# or
venv\Scripts\activate  # Windows

# Install development dependencies
pip install -r requirements-dev.txt
```

### 4. Run Tests

```bash
# Unit tests
pytest tests/unit/ -v

# Integration tests
pytest tests/integration/ -v

# All tests with coverage
pytest --cov=drone_telemetry_system --cov-report=html
```

## Code Style

### Python

Follow **PEP 8** with these specific rules:

```python
# Good
def process_telemetry(sample: TelemetrySample) -> Dict[str, Any]:
    """Process a single telemetry sample.
    
    Args:
        sample: Telemetry sample object
        
    Returns:
        Dictionary with processed data
    """
    return {"timestamp": sample.ts_ms, "data": sample.to_dict()}

# Bad
def process_telemetry(sample):
    return {"timestamp": sample.ts_ms, "data": sample.to_dict()}
```

**Tools**:
```bash
# Format code
black drone_telemetry_system/

# Check style
flake8 drone_telemetry_system/ --max-line-length=100

# Type checking
mypy drone_telemetry_system/
```

### C++

Follow **Google C++ Style Guide** (C++17):
