# 07 - Development Plan

Atomic execution plan for Owl. Each step is a single commit.

## Status Legend

- [ ] Not started
- [x] Completed
- [~] In progress

---

## Phase 0: Project Scaffolding

| # | Task | Commit | Status |
|---|------|--------|--------|
| 0.1 | Create Package.swift with Owl (executable) + OwlCore (library) + OwlCoreTests targets, macOS 14.0 | c822f1e | [x] |
| 0.2 | Create directory structure: Sources/Owl/, Sources/OwlCore/, Tests/OwlCoreTests/ with placeholder files | c822f1e | [x] |
| 0.3 | Add .swiftlint.yml (strict mode) + install SwiftLint config | c822f1e | [x] |
| 0.4 | Add Git Hooks: scripts/pre-commit.sh (UT + Lint), scripts/pre-push.sh (Integration), .githooks setup | c822f1e | [x] |
| 0.5 | Update .gitignore for SPM (.build/, .swiftpm/) | c822f1e | [x] |
| 0.6 | Verify: `swift build` + `swift test` + `swiftlint` all pass | c822f1e | [x] |

---

## Phase 1: Core Detection Engine (TDD)

### Phase 1.1: Data Models

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1.1.1 | Define `Severity` enum (normal/info/warning/critical, Comparable, Codable) + UT | 35eda80 | [x] |
| 1.1.2 | Define `LogEntry` struct (timestamp, process, processID, subsystem, category, messageType, eventMessage) + UT | fe097d1 | [x] |
| 1.1.3 | Define `Alert` struct (detectorID, severity, title, description, suggestion, timestamp, ttl) + UT | a627a6e | [x] |

### Phase 1.2: Algorithm Engines

#### 1.2a: ThresholdDetector

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1.2a.1 | Define `PatternDetector` protocol (id, isEnabled, accepts, process, tick) | 3bed553 | [x] |
| 1.2a.2 | Define `Comparison` enum (.lessThan/.greaterThan) and `ThresholdConfig` | f4fbffb | [x] |
| 1.2a.3 | Implement `ThresholdDetector` state machine (Normal→Pending→Warning→Critical→Recovery) + UT for all transitions | f4fbffb | [x] |
| 1.2a.4 | Add debounce logic to ThresholdDetector + UT for timing | f4fbffb | [x] |
| 1.2a.5 | Add recovery threshold with hysteresis + UT | f4fbffb | [x] |

#### 1.2b: RateDetector

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1.2b.1 | Implement `SlidingWindowCounter` (Ring Buffer time buckets, O(1) increment/advance/total) + UT | 0b7c2b2 | [x] |
| 1.2b.2 | UT: Ring Buffer boundary conditions (full window, cross-window advance, full expiry) | 0b7c2b2 | [x] |
| 1.2b.3 | Implement `RateDetector` with grouped counting (Dictionary<String, SlidingWindowCounter>) + UT | 2b03e8b | [x] |
| 1.2b.4 | Add group limit + LRU eviction to RateDetector + UT | 2b03e8b | [x] |
| 1.2b.5 | Add cooldown mechanism + UT | 2b03e8b | [x] |

#### 1.2c: StateDetector

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1.2c.1 | Implement `StateDetector` (Created/Released pair tracking) + UT for normal pairing | f2b9499 | [x] |
| 1.2c.2 | Add tick()-based leak detection (warning/critical age thresholds) + UT | f2b9499 | [x] |
| 1.2c.3 | Add maxTracked limit + FIFO eviction + cleanup + UT | f2b9499 | [x] |

### Phase 1.3: Pattern Configurations (14 patterns)

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1.3.1 | Create `TestFixtures.swift` with real log samples from docs for all 14 patterns | 332053d | [x] |
| 1.3.2 | P01 ThermalPattern (ThresholdDetector config + regex) + UT with real log | 717c945 | [x] |
| 1.3.3 | P02 CrashLoopPattern (RateDetector config + regex) + UT | fecdc39 | [x] |
| 1.3.4 | P03 DiskFlushPattern (ThresholdDetector config + regex) + UT | 16e97e0 | [x] |
| 1.3.5 | P04 WiFiPattern (ThresholdDetector config + dual metrics) + UT | c31b30d | [x] |
| 1.3.6 | P05 SandboxPattern (RateDetector config + regex) + UT | 8931527 | [x] |
| 1.3.7 | P06 SleepAssertionPattern (StateDetector config + regex) + UT | 88c3251 | [x] |
| 1.3.8 | P07 CrashSignalPattern (RateDetector config + regex) + UT | 43dcac8 | [x] |
| 1.3.9 | P08 BluetoothPattern (RateDetector config + regex) + UT | 5877220 | [x] |
| 1.3.10 | P09 TCCPattern (RateDetector config + regex) + UT | 365e442 | [x] |
| 1.3.11 | P10 JetsamPattern (Threshold + Rate hybrid) + UT | c8a34ab | [x] |
| 1.3.12 | P11 AppHangPattern (RateDetector config + regex) + UT | f07f5c2 | [x] |
| 1.3.13 | P12 NetworkPattern (RateDetector global aggregate) + UT | aaf0276 | [x] |
| 1.3.14 | P13 USBPattern (RateDetector config + regex) + UT | ba4368b | [x] |
| 1.3.15 | P14 DarkWakePattern (RateDetector global aggregate) + UT | f273481 | [x] |
| 1.3.16 | PatternCatalog factory (creates all 14 detectors) + UT | 61c81cb | [x] |

### Phase 1.4: DetectorPipeline

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1.4.1 | Implement `DetectorPipeline` actor (dispatch LogEntry to detectors, accepts→process flow) + UT | 4a9aece | [x] |
| 1.4.2 | Add performTick() periodic maintenance + UT | 4a9aece | [x] |
| 1.4.3 | Integration test: full pipeline with multiple detectors firing simultaneously | 4a9aece | [x] |

### Phase 1.5: AlertStateManager

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1.5.1 | Implement `AlertStateManager` (receive alerts, pending→active debounce) + UT | 542fd28 | [x] |
| 1.5.2 | Add TTL expiry + alertHistory + UT | 542fd28 | [x] |
| 1.5.3 | Add severity aggregation (currentSeverity = max of all confirmed) + UT | 542fd28 | [x] |
| 1.5.4 | Add same-detector alert update/upgrade + UT | 542fd28 | [x] |
| 1.5.5 | Coverage check: verify 95%+ on all Phase 1 code | | [ ] |

---

## Phase 2: Log Stream Reader + System Metrics

| # | Task | Commit | Status |
|---|------|--------|--------|
| 2.1 | Implement ndjson parser (JSON line → LogEntry) + UT with valid/invalid/incomplete JSON | | [ ] |
| 2.2 | Implement predicate builder (combine all pattern predicates) + UT | | [ ] |
| 2.3 | Implement `LogStreamReader` (Foundation.Process lifecycle, stdout Pipe, async line reading) + UT | | [ ] |
| 2.4 | Add exponential backoff restart on crash (max 30s) + UT | | [ ] |
| 2.5 | Implement `SystemMetricsPoller` (CPU via host_statistics, memory via host_statistics64) + UT | | [ ] |
| 2.6 | Integration test: real log stream start/read/stop | | [ ] |

---

## Phase 3: Menu Bar UI

| # | Task | Commit | Status |
|---|------|--------|--------|
| 3.1 | Create `OwlApp.swift` @main entry + `AppDelegate` with NSStatusItem + LSUIElement | | [ ] |
| 3.2 | Implement `StatusItemController` (4 icon states with SF Symbols + color) + UT | | [ ] |
| 3.3 | Add icon animations (pulse for critical, flash green for recovery) | | [ ] |
| 3.4 | Create NSPopover + left-click toggle + right-click context menu | | [ ] |
| 3.5 | Implement `SystemOverviewBar` (CPU/MEM/TEMP gauges with color thresholds) | | [ ] |
| 3.6 | Implement `ActiveAlertsSection` + `AlertRow` (severity icon, title, description, suggestion) | | [ ] |
| 3.7 | Implement empty state ("系统运行正常") | | [ ] |
| 3.8 | Implement `RecentHistorySection` (last 5 expired alerts) | | [ ] |
| 3.9 | Implement `BottomBar` (Settings + Quit buttons) | | [ ] |
| 3.10 | Wire data binding: AlertStateManager → SwiftUI, SystemMetricsPoller → SwiftUI | | [ ] |

---

## Phase 4: Settings

| # | Task | Commit | Status |
|---|------|--------|--------|
| 4.1 | Implement `AppSettings` (UserDefaults wrapper for all settings) + UT | | [ ] |
| 4.2 | Settings Tab 1: General (auto-launch via SMAppService, refresh interval) | | [ ] |
| 4.3 | Settings Tab 2: Detector toggles (14 switches, default all on) | | [ ] |
| 4.4 | Settings Tab 3: About (version, name, icon) | | [ ] |
| 4.5 | Wire settings to DetectorPipeline (enable/disable detectors, refresh interval) | | [ ] |

---

## Phase 5: Integration & Distribution

| # | Task | Commit | Status |
|---|------|--------|--------|
| 5.1 | Full pipeline integration: LogStreamReader → Pipeline → AlertStateManager → UI | | [ ] |
| 5.2 | Performance validation: CPU < 1%, RAM < 30 MB | | [ ] |
| 5.3 | Add Info.plist + Hardened Runtime entitlements | | [ ] |
| 5.4 | Create build + notarization scripts (scripts/build.sh, scripts/notarize.sh) | | [ ] |
| 5.5 | Create DMG packaging script | | [ ] |
| 5.6 | L4 UI Tests (XCUITest): Menu Bar click → Popover, Settings navigation | | [ ] |
| 5.7 | Final coverage report + README update | | [ ] |

---

## Test Architecture

| Layer | Type | Tool | Trigger | Target |
|-------|------|------|---------|--------|
| L1 | Unit Tests | `swift test` | pre-commit | 95%+ coverage |
| L2 | SwiftLint | `swiftlint --strict` | pre-commit | Zero errors/warnings |
| L3 | Integration Tests | `swift test --filter Integration` | pre-push | Pipeline end-to-end |
| L4 | UI Tests | XCUITest | On-demand | Menu Bar interaction |

## Commit Convention

- `feat: <description>` — new feature
- `test: <description>` — test only (TDD red phase)
- `fix: <description>` — bug fix
- `refactor: <description>` — code improvement
- `chore: <description>` — tooling, config
