# Owl

**macOS system health monitor in the Menu Bar.**

Owl watches the macOS unified log stream in real-time, detects known anomaly patterns (thermal throttling, crash loops, disk issues, WiFi degradation, etc.), and surfaces them as visual alerts in the Menu Bar — so problems never go unnoticed.

## Why

macOS already logs every significant system event. Thermal throttling, process crashes, memory pressure kills, Bluetooth disconnects — it's all there in the unified log. But nobody watches the log. Owl does.

## How It Works

1. Spawns `/usr/bin/log stream --style ndjson` with a predicate filter (kernel-side, minimal overhead)
2. Parses each JSON log entry and routes it through 14 pattern detectors
3. Each detector uses one of three simple algorithms: **Threshold**, **Rate counting**, or **State tracking**
4. Alerts appear as color changes on the Menu Bar icon; click for details

**Performance**: RAM ~12 MB, zero external dependencies, 100% native Swift.

## Detectable Patterns

| # | Pattern | Algorithm |
|---|---------|-----------|
| 1 | Thermal throttling | Threshold |
| 2 | Process crash-loop | Rate |
| 3 | APFS disk flush delay | Threshold |
| 4 | WiFi signal degradation | Threshold |
| 5 | Sandbox violation storm | Rate |
| 6 | Sleep assertion leak | State |
| 7 | Process crash signals | Rate |
| 8 | Bluetooth disconnects | Rate |
| 9 | TCC permission storm | Rate |
| 10 | Jetsam memory kill | Threshold + Rate |
| 11 | App hang / not responding | Rate |
| 12 | Network connection failures | Rate |
| 13 | USB device errors | Rate |
| 14 | DarkWake abnormal wakes | Rate |

## Requirements

- macOS 14 Sonoma or later
- No external dependencies — 100% Apple native frameworks

## Install

Download the latest `Owl.dmg` from [Releases](https://github.com/nocoo/owl/releases), open it, and drag `Owl.app` to `/Applications`.

Owl runs as a Menu Bar app (no Dock icon). Click the owl icon to see system status, active alerts, and recent history. Right-click for Settings and Quit.

## Build from Source

```bash
# Clone
git clone https://github.com/nocoo/owl.git
cd owl

# Build and run (debug)
swift build && .build/debug/Owl

# Build release .app bundle
./scripts/build.sh

# Build with code signing (for distribution)
./scripts/build.sh --sign "Developer ID Application: Your Name (TEAMID)"

# Package as DMG
./scripts/package-dmg.sh

# Notarize (requires Apple Developer credentials)
./scripts/notarize.sh        # notarize .app
./scripts/notarize.sh --dmg  # notarize .dmg
```

## Test

```bash
# Run all 366 tests (38 suites)
swift test

# Run only integration tests
swift test --filter Integration

# Lint
swiftlint --strict
```

Test architecture:
- **L1**: 366 unit + integration tests via Swift Testing framework
- **L2**: SwiftLint strict mode (zero violations)
- **L3**: 11 end-to-end integration tests (log stream → pipeline → alerts)

## Project Structure

```
owl/
├── Sources/
│   ├── Owl/                    # App entry point (AppDelegate, Menu Bar)
│   └── OwlCore/                # Core library (all testable logic)
│       ├── Models/             # LogEntry, Alert, Severity
│       ├── Detectors/          # ThresholdDetector, RateDetector, StateDetector
│       ├── Patterns/           # 14 pattern configs + PatternCatalog
│       ├── Pipeline/           # DetectorPipeline, AlertStateManager
│       ├── Services/           # LogStreamReader, SystemMetricsPoller
│       ├── Settings/           # AppSettings, DetectorCatalog
│       └── UI/                 # SwiftUI views, AppState, StatusItemMapper
├── Tests/OwlCoreTests/         # 366 tests in 38 suites
├── scripts/                    # build, notarize, DMG packaging
└── docs/                       # Design documentation
```

## Documentation

Detailed design docs in [`docs/`](docs/):

1. [Project Overview](docs/01-overview.md)
2. [Technical Architecture](docs/02-architecture.md)
3. [Detectable Pattern Catalog](docs/03-patterns.md)
4. [Detection Algorithm Design](docs/04-detection-algorithms.md)
5. [Menu Bar UI Design](docs/05-ui-design.md)
6. [Build & Distribution](docs/06-distribution.md)
7. [Development Plan](docs/07-development-plan.md)

## License

See [LICENSE](LICENSE).
