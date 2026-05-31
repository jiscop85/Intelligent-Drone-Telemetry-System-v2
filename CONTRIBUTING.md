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

```cpp
// Good
class TelemetryCollector {
 public:
  TelemetryCollector(const std::string& mqtt_uri);
  ~TelemetryCollector() = default;
  
  bool connect_mqtt();
  void publish_snapshot();
  
 private:
  std::string mqtt_uri_;
  std::mutex state_mutex_;
};

// Bad
class TelemetryCollector {
public:
    TelemetryCollector(std::string mqtt_uri) { }  // No const&
    bool ConnectMqtt() { }  // Wrong naming
};
```

**Tools**:
```bash
# Format C++
clang-format -i drone_telemetry_system/cpp_collector/*.cpp

# Lint
cppcheck drone_telemetry_system/cpp_collector/
```

## Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code restructuring
- `docs`: Documentation updates
- `test`: Test additions
- `chore`: Maintenance, dependency updates
- `perf`: Performance improvements

**Example**:
```
feat(dashboard): add export to Parquet format

- Implement to_parquet() in TelemetryStore
- Add export button in PyQt6 UI
- Handle empty data gracefully

Closes #123
```

## Pull Request Process

### 1. Prepare Your Branch

```bash
# Keep up with main
git fetch upstream
git rebase upstream/main

# Push to your fork
git push origin feature/your-feature-name
```

### 2. Create PR on GitHub

**PR Title**:
```
[TYPE] Short description (e.g., "FEAT: Add CSV export to dashboard")
```

**PR Description** (use template):
```markdown
## What does this PR do?
Brief description

## Why are we doing this?
Problem statement

## How did you test this?
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing steps:
  1. Start MQTT broker
  2. Run collector
  3. Open dashboard
  4. Verify [feature]

## Checklist
- [ ] Code follows style guide
- [ ] New functions have docstrings
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes
```

### 3. Code Review

- Respond to reviewer comments professionally
- Request review from experts in that area
- Address all suggestions before merging

### 4. Merge

Once approved:
```bash
# Ensure latest
git pull upstream main

# Merge locally and push (maintainers only)
git merge --squash origin/feature/your-feature-name
git commit -m "Merge PR #XXX: Feature description"
git push upstream main
```

## Adding a New Feature

### Example: Add Support for External IMU

**1. Plan** (design document):
```markdown
# Add External IMU Support

## Motivation
Some users want higher IMU sample rates

## Design
- Add ExtImuReader class in cpp_collector/
- Subscribe to /external_imu topic
- Merge with MAVSDK IMU data

## Files Changed
- telemetry_state.hpp (add external_imu field)
- main.cpp (new subscriber)
- main.py (dashboard handling)

## Testing
- Unit test for ExtImuReader
- Integration test with mock IMU
```

**2. Implement**:
```cpp
// cpp_collector/external_imu.hpp
class ExtImuReader {
 public:
  void on_imu_data(const sensor_msgs::Imu& msg);
  
 private:
  std::queue<sensor_msgs::Imu> imu_queue_;
};

// Add to main.cpp
ExtImuReader external_imu;
subscriber = nh.subscribe("/external_imu", 10, 
    &ExtImuReader::on_imu_data, &external_imu);
```

**3. Test**:
```cpp
// tests/unit/test_external_imu.cpp
TEST(ExtImuReader, QueuesMessages) {
    ExtImuReader reader;
    sensor_msgs::Imu msg;
    reader.on_imu_data(msg);
    EXPECT_EQ(reader.queue_size(), 1);
}
```

**4. Document**:
```markdown
# External IMU Support

## Installation
1. Install ROS2 package for IMU driver
2. Configure rostopic in .env

## Usage
imu_reader = ExtImuReader()
```

**5. Update Roadmap**:
- Add to Phase X
- Update documentation

## Testing Guidelines

### Unit Tests (C++)

```cpp
#include <gtest/gtest.h>
#include "telemetry_state.hpp"

TEST(TelemetryState, InitializesWithNaN) {
    TelemetryState state;
    EXPECT_TRUE(std::isnan(state.lat));
    EXPECT_TRUE(std::isnan(state.lon));
    EXPECT_EQ(state.flight_id, "");
}

TEST(TelemetryState, ToJsonRoundTrip) {
    TelemetryState state;
    state.lat = 37.7749;
    state.lon = -122.4194;
    auto json = state.to_json();
    EXPECT_EQ(json["lat"], 37.7749);
}
```

### Integration Tests (Python)

```python
import pytest
from unittest.mock import Mock
from dashboard.telemetry_store import TelemetryStore

@pytest.fixture
def store():
    return TelemetryStore()

def test_add_sample(store):
    sample = TelemetrySample(
        ts_ms=1000,
        lat=37.7749,
        lon=-122.4194,
        # ... other fields
    )
    store.add(sample)
    assert len(store.samples) == 1
    assert store.latest == sample

def test_export_csv(store, tmp_path):
    # Add samples
    store.add(sample1)
    store.add(sample2)
    
    # Export
    csv_path = tmp_path / "export.csv"
    store.to_csv(str(csv_path))
    
    # Verify
    assert csv_path.exists()
    lines = csv_path.read_text().split('\n')
    assert len(lines) == 4  # Header + 2 samples + blank line
```
