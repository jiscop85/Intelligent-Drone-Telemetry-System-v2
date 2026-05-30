# Architecture & Design Documentation

## System Architecture

### High-Level Components

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Drone / Autopilot                            │
│              (PX4, ArduCopter, MAVSDK-compatible)                   │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                    MAVLink Protocol (UDP 14540)
                               │
                ┌──────────────↓──────────────┐
                │                             │
        ┌───────┴─────────┐          ┌────────┴────────┐
        │  C++ Collector  │          │  MAVSDK Library │
        │                 │          │                 │
        │ - Thread-safe   │          │ ✓ Position      │
        │ - JSON Schema   │          │ ✓ Altitude      │
        │ - Mutex Locks   │          │ ✓ Battery       │
        │ - 10-20 Hz      │          │ ✓ IMU           │
        │ - 50 MB RAM     │          │ ✓ Velocity NED  │
        └────────┬────────┘          │ ✓ Wind          │
                 │                   │ ✓ Armed/In-air  │
           JSON Messages             │ ✓ GPS Fix       │
           (100ms loop)              │ ✓ Signal OK     │
                 │                   └─────────────────┘
                 │
         MQTT Publication
         (QoS 1, 10 Hz)
                 │
        ┌────────↓────────┐
        │   MQTT Broker   │
        │   (Mosquitto)   │
        │                 │
        │ Topic: drone/   │
        │ telemetry       │
        └────────┬────────┘
                 │
        ┌────────┴────────┬────────────┬──────────────┐
        ↓                 ↓            ↓              ↓
    ┌────────┐      ┌──────────┐  ┌─────────┐   ┌────────┐
    │Python  │      │ROS2      │  │OpenCV   │   │Anomaly │
    │PyQt6   │      │Bridge    │  │Overlay  │   │Engine  │
    │Dashboard       │          │  │         │   │        │
    │        │      │Nodes:    │  │Video    │   │Detection
    │✓Status │      │- /drone/ │  │Telemetry    │        │
    │✓Charts │      │  gps     │  │Overlay      │✓ Alert │
    │✓Map    │      │- /drone/ │  │Display      │✓ Train │
    │✓Export │      │  velocity│  │             │✓ Score │
    └────┬───┘      └──────────┘  └─────────────┘   └────┬───┘
         │                │              │              │
    ┌────↓──────┐   ┌────↓──┐      ┌────↓────┐   ┌────↓────┐
    │Data Store │   │ROS2   │      │Files    │   │ML Model │
    │           │   │Topics │      │         │   │         │
    │✓SQLite*   │   │       │      │✓Video   │   │✓IsoForest
    │✓CSV       │   │Pub    │      │✓GeoJSON │   │✓joblib  │
    │✓GeoJSON   │   │Sub    │      │✓CSV     │   │✓joblib  │
    └───────────┘   └───────┘      └─────────┘   └─────────┘
    
    * Phase 1 upgrade
```

## Data Flow Diagram

```
Time-Synchronized MAVSDK Callbacks
├─ Position (lat, lon) ─────┐
├─ Altitude (abs, rel) ──────┤
├─ Battery (V, %) ──────────┤
├─ IMU (ax,ay,az,gx,gy,gz) ─┤
├─ Velocity NED (vn,ve,vd) ──┤
├─ Wind (wn,we,wd) ─────────┤
├─ Armed ───────────────────┤
├─ In-air ──────────────────┤
└─ GPS Fix + Signal ────────┘
        │
        │ Mutex-protected
        │ update to state_
        │
        ↓
   TelemetryState
   (shared memory)
        │
        │ Every 100ms
        │
        ↓
   to_json()
   (serialization)
        │
        │
        ↓
   MQTT Publish
   (QoS=1)
        │
   ┌────┴─────┬──────────┬─────────┐
   ↓          ↓          ↓         ↓
Dashboard  ROS2 Bridge Overlay  Analytics
   │          │          │         │
   └──────────┴──────────┴─────────┘
        ↓
   Storage Layer*
   (SQLite/CSV)
   
   * Phase 1
```

## Thread Safety Model

### C++ Collector Architecture

```
┌──────────────────────────────────────────────┐
│         TelemetryCollector                   │
├──────────────────────────────────────────────┤
│                                              │
│  ┌─ Main Thread                              │
│  │  ├─ MQTT Connect                          │
│  │  ├─ MAVSDK Init                           │
│  │  ├─ Subscribe callbacks                   │
│  │  └─ Publisher Thread spawn                │
│  │                                           │
│  ├─ Publisher Thread (100ms loop)            │
│  │  ├─ snapshot_state()  ← LOCK              │
│  │  ├─ to_json()                             │
│  │  ├─ MQTT Publish                          │
│  │  └─ sleep 100ms                           │
│  │                                           │
│  └─ MAVSDK Callback Threads (internal)       │
│     ├─ position_cb     → state_ update ← LOCK
│     ├─ altitude_cb     → state_ update ← LOCK
│     ├─ battery_cb      → state_ update ← LOCK
│     ├─ imu_cb          → state_ update ← LOCK
│     ├─ velocity_cb     → state_ update ← LOCK
│     ├─ wind_cb         → state_ update ← LOCK
│     ├─ armed_cb        → state_ update ← LOCK
│     └─ in_air_cb       → state_ update ← LOCK
│
│  ┌─────────────────────────────────┐
│  │  TelemetryState state_          │
│  │  protected by state_mutex_      │
│  │                                 │
│  │  All fields initialized to NAN │
│  │  Updated asynchronously         │
│  │  Atomic timestamp on snapshot   │
│  └─────────────────────────────────┘
│
└──────────────────────────────────────────────┘
```

## Module Responsibilities

### C++ Collector (`cpp_collector/`)
- **Input**: MAVSDK telemetry streams
- **Processing**: 
  - Asynchronous callback registration
  - Mutex-protected state management
  - JSON serialization
- **Output**: MQTT messages (JSON, 10 Hz)
- **Guarantees**:
  - No data loss (QoS 1)
  - Atomic timestamps
  - Memory-safe (mutex/lock guards)

### Python Dashboard (`dashboard/`)
- **Input**: MQTT telemetry + user interactions
- **Processing**:
  - Multi-threaded MQTT worker
  - Real-time chart updates
  - Map synchronization
  - CSV/GeoJSON export
- **Output**: PyQt6 UI + files
- **Guarantees**:
  - Non-blocking UI (separate thread)
  - <250ms visual refresh
  - 5000-sample ring buffer

### Analytics Engine (`analytics/`)
- **Input**: Telemetry samples (dict)
- **Processing**:
  - IsolationForest anomaly detection
  - Feature normalization
  - Real-time scoring
- **Output**: Anomaly label ("normal", "anomaly", "warning")
- **Guarantees**:
  - <10ms scoring latency
  - Fallback heuristics
  - Model persistence

### ROS2 Bridge (`ros2_bridge/`)
- **Input**: MQTT telemetry
- **Processing**:
  - Message format conversion
  - ROS2 type mapping
- **Output**: ROS2 topics (10 Hz)
  - `/drone/telemetry/raw` (String)
  - `/drone/gps` (NavSatFix)
  - `/drone/velocity` (TwistStamped)
- **Guarantees**:
  - Same timing as MQTT
  - Standard ROS2 types

### Vision Module (`vision/`)
- **Input**: Webcam + MQTT telemetry
- **Processing**:
  - OpenCV overlay rendering
  - Telemetry label placement
- **Output**: X11 window with overlay
- **Guarantees**:
  - Live video (camera FPS)
  - Smooth overlay updates

## Data Schema Evolution

### Current (MVP)
- 25 fields
- NED coordinate frame
- Millisecond timestamp
- Flight ID tracking

### Phase 1 (Storage)
- Add to-be-determined fields
- Database indices
- CSV column mapping
- GeoJSON properties

### Phase 2 (Analytics)
- Anomaly flag
- Alert metadata
- Training annotations
- Signal quality indicators

### Phase 3+ (Extended)
- Camera metadata
- Feature descriptors
- Fusion results
- User annotations

## Performance Characteristics

### Memory Usage (typical)
```
C++ Collector:        50-100 MB
  ├─ MAVSDK library:   30 MB
  ├─ MQTT client:      10 MB
  └─ TelemetryState:    1 KB
  
Python Dashboard:    200-400 MB
  ├─ PyQt6:          100 MB
  ├─ Data store:      50 MB (5000 samples)
  ├─ Plots:           40 MB
  ├─ Map:             20 MB
  └─ Python runtime:  80 MB

Total system:       300-500 MB
```

### CPU Usage (typical)
```
Idle:
  C++ Collector:     <1%
  Dashboard:         5-10%
  
Active:
  C++ Collector:     5-10%  (MQTT + JSON)
  Dashboard:        20-30%  (rendering + updates)
  
Peak (export):
  Dashboard:        50-80%  (CSV write)
```

### Network
```
MQTT bandwidth:      ~2 KB/s (10 Hz, 200 bytes/msg)
Mosquitto CPU:      <2% (10 clients)
Broker memory:      ~10 MB
```

### Latency
```
MAVSDK → Collector:      <1ms (internal)
Collector → MQTT:       <5ms (local)
MQTT → Dashboard:       <10ms (network)
Dashboard update:       <50ms (UI thread)
Total end-to-end:       <100ms (10 Hz)
```

## Scalability Considerations

### Single Drone (MVP)
- 1 collector → 1 broker → N consumers
- Bandwidth: ~2 KB/s
- Broker: Mosquitto on laptop

### Multi-Drone (Phase 1-2)
- N collectors → 1 broker → N consumers
- Topics: drone/{id}/telemetry
- Bandwidth: ~2N KB/s
- Broker: Mosquitto on server

### Enterprise (Phase 3+)
- N collectors → Cloud broker → Web dashboard
- InfluxDB time-series storage
- Kafka for high-volume scenarios
- Grafana + custom analytics

## Extension Points

### Easy to Add
1. New telemetry field:
   - Add to TelemetryState
   - Subscribe in MAVSDK
   - Update JSON mapping
   - Display in dashboard

2. New export format:
   - Implement to_format() in TelemetryStore
   - Wire up button in dashboard
   - Test with real data

3. New alert rule:
   - Add rule to AlertEngine
   - Configure threshold
   - Test detection
   - Enable/disable in UI

### Harder to Add
1. New message format:
   - Requires producer/consumer updates
   - Schema migration
   - Backward compatibility

2. New database backend:
   - Connection pool setup
   - Query API design
   - ORM mapping

3. New ROS2 message type:
   - Type definition
   - Serialization
   - All clients update

## Known Limitations

### Current (MVP)
- Single drone only (can extend with flight_id)
- No data storage (Phase 1)
- No replay (Phase 2)
- No real-time alerts (Phase 3)
- Linux/macOS only (Docker for Windows)
- Requires manual MQTT startup
- PyQt6 UI not web-accessible

### By Design
- NED frame required (autopilot standard)
- 10 Hz max (MAVSDK limitation)
- JSON only (extensible to protobuf)
- Timestamp in milliseconds (precision limit)

### Future Mitigations
- Docker containers (eliminate OS issues)
- Systemd services (autostart)
- Web dashboard (browser access)
- Higher-frequency IMU (separate stream)
- Multiple output formats (Parquet, HDF5)

## Testing Strategy

### Unit Tests (C++)
```cpp
TEST(TelemetryState, ToJson) {
    TelemetryState state;
    auto json = state.to_json();
    EXPECT_EQ(json["ts_ms"].is_number(), true);
}
```

### Integration Tests (Python)
```python
def test_mqtt_dashboard_flow():
    store = TelemetryStore()
    sample = TelemetrySample(...)
    store.add(sample)
    assert len(store.samples) == 1
```

### System Tests
```bash
# Start all components
./scripts/start_all.sh --docker

# Monitor
mosquitto_sub -t "drone/telemetry" -v

# Verify end-to-end
# Dashboard displays live data
```

---

**Author**: Development Team  
**Last Updated**: 2026-05-29  
**Version**: 2.0
