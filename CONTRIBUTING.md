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

### System Tests

```bash
#!/bin/bash
# tests/system_test.sh

# Start MQTT
docker-compose up -d mosquitto

# Start collector
./build/telemetry_collector &
COLLECTOR_PID=$!

# Start dashboard in background
python3 -u dashboard/app.py &
DASHBOARD_PID=$!

# Publish test message
mosquitto_pub -h localhost -t drone/telemetry -m '{
    "ts_ms": 1000,
    "lat": 37.7749,
    "lon": -122.4194
}'

# Check dashboard received it
sleep 1
ps -p $DASHBOARD_PID > /dev/null || echo "Dashboard crashed"

# Cleanup
kill $COLLECTOR_PID $DASHBOARD_PID
docker-compose down
```

## Documentation

### Python Docstrings

Use Google style:
```python
def calculate_speed(v_north: float, v_east: float, v_down: float) -> float:
    """Calculate total ground speed from NED velocity components.
    
    Args:
        v_north: North velocity (m/s)
        v_east: East velocity (m/s)
        v_down: Down velocity (m/s)
        
    Returns:
        Ground speed magnitude (m/s)
        
    Raises:
        ValueError: If any input is NaN
        
    Examples:
        >>> calculate_speed(10.0, 5.0, 0.0)
        11.18
    """
    if math.isnan(v_north) or math.isnan(v_east) or math.isnan(v_down):
        raise ValueError("Velocity components cannot be NaN")
    return math.sqrt(v_north**2 + v_east**2 + v_down**2)
```

### C++ Comments

```cpp
// Brief description of what this function does
// Explain the why, not the what (code shows the what)
bool TelemetryCollector::publish_snapshot() {
    std::lock_guard<std::mutex> lock(state_mutex_);
    
    // Atomically capture timestamp and state
    auto now = std::chrono::system_clock::now();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()).count();
    
    state_.ts_ms = ms;
    auto json = state_.to_json();
    
    // QoS 1 ensures at-least-once delivery
    return mqtt_client_->publish(mqtt_topic_, json.dump());
}
```

## Performance Considerations

### Python

```python
# Good: Avoid repeated list appends
samples = []
for i in range(10000):
    samples.append(process(i))  # O(n) worst case due to reallocation

# Better: Use deque with maxlen
from collections import deque
samples = deque(maxlen=10000)
for i in range(10000):
    samples.append(process(i))  # Always O(1)
```

### C++

```cpp
// Good: Reserve space upfront
std::vector<TelemetrySample> samples;
samples.reserve(10000);  // Avoid reallocations
for (int i = 0; i < 10000; i++) {
    samples.push_back(process(i));
}

// Avoid: String concatenation in loop
std::string result = "";
for (int i = 0; i < 1000; i++) {
    result += "data";  // Creates new string each iteration
}
```

## Reporting Issues

Use GitHub Issues with this template:

```markdown
## Bug Report

### Description
What's the problem?

### Steps to Reproduce
1. Start MQTT broker
2. Launch collector with URL: ...
3. Wait 10 seconds
4. Observe: [issue]

### Expected Behavior
What should happen?

### Actual Behavior
What actually happened?

### Environment
- OS: Ubuntu 22.04
- Python: 3.10
- MAVSDK: Latest
- Collector: v2.0.0

### Logs
[Paste relevant log output]

### Additional Context
[Screenshots, error traces, etc.]
```

## Release Process

### Version Numbering: Semantic Versioning (MAJOR.MINOR.PATCH)

```
2.0.0  MVP v2 release
2.0.1  Bug fix
2.1.0  Phase 1 (SQLite storage)
3.0.0  Major refactor or breaking changes
```

### Release Checklist

- [ ] All tests passing
- [ ] Update ROADMAP.md with completed items
- [ ] Update CHANGELOG.md
- [ ] Tag commit: `git tag -a v2.0.1 -m "Release v2.0.1"`
- [ ] Push tags: `git push upstream --tags`
- [ ] Create GitHub Release with notes

## Need Help?

- **General Questions**: Discussions tab
- **Bug Reports**: Issues tab
- **Design Discussion**: Use wiki or discussions
- **Code Review**: Open a PR

---

**Last Updated**: 2026-05-29  
**Maintained by**: Development Team
