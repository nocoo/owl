# Changelog

## v1.5.0

### Features

- Add click-to-copy for all metric sections (CPU, Memory, Disk, Power, Temperature, Network, Processes) — click any section to copy a formatted snapshot to clipboard
- Add `CopyableSection` wrapper with green "Copied" feedback badge in section header and hover highlight

### Bug Fixes

- Fix missed clicks in metric sections by moving `contentShape` inside button label to prevent ScrollView gesture conflicts

### Tests

- Add 34 tests for clipboard text generation across all metric sections

## v1.4.0

### Features

- Add battery wattage display in Power section via IOKit (Voltage × Amperage)
- Refine popover section labels for CPU, memory, disk, and power

### Bug Fixes

- Fix CPU usage calculation: convert Mach absolute ticks to nanoseconds via `mach_timebase_info` and remove double-counted thread times
- Fix real-time top processes display by expanding process sampling range
- Align full-width row bars (MetricRow, InfoRow, SpeedRow) with two-column layout edges
- Restore full state text in power section (Charging/Plugged/Battery)

### Refactoring

- Standardize all 2-column bar layouts (CoreMiniRow, DualThroughputRow) to TempMiniRow spec: label 38pt, bar flex, value 28pt, spacing 3, infoRowHeight 12pt
- Merge memory info rows (Cache/Avail + PageIn/PageOut) into single 4-column row
- Merge power info rows (State/Cycles/Condition) into single 4-column row with wattage
- Compact disk, memory, and power section layouts

### Tests

- Add TopProcessProvider tests for sampling and CPU calculation

## v1.3.0

### Features

- Add HID thermal sensor support via `IOHIDEventSystemClient` for reliable CPU temperature on Apple Silicon (replaces unreliable SMC `Tp*` keys)
- Add `HIDThermalBridge` Obj-C target and `HIDTemperatureProvider` Swift wrapper with automatic chip generation detection (M1/M2 pACC/eACC, M3/M4 PMU tdie)
- Add smooth animation to MiniBar and temperature text transitions
- Show aggregated CPU/GPU/SSD/Battery temperatures instead of raw HID sensor dump

### Bug Fixes

- Fix CPU temperature flickering on Apple Silicon (M4 Max) — SMC `Tp*` keys return garbage data; now uses HID sensors as primary source
- Tighten temperature validation range to 5–130°C to reject spurious readings
- Cache last-known-good temperature to survive sporadic bad reads
- Reset SMC input/output structs before second call to prevent stale data
- Cache IOKit SMC connection for provider lifetime instead of per-call open/close
- Add carry-over buffer to prevent pipe-fragmented line drops in log stream
- Retain log stream reader reference to prevent subprocess leak on shutdown
- Handle `\uXXXX` unicode escapes and surrogate pairs in fast JSON parser
- Defer `proc_name` calls to top-N candidates only to reduce syscall overhead
- Add independent timer flush to prevent entries stuck in batch during low traffic
- Annotate `AlertStateManager` with `@MainActor` for compile-time isolation

### Performance

- Replace O(n log n) sort with linear scan in LRU eviction
- Avoid temporary set allocation in `distinctCount` by counting incrementally

### Refactoring

- Migrate `AppState` from `ObservableObject` to `@Observable` for property-level tracking

### Tests

- Add unit tests for SMC temperature decoding and validation range
- Add 12 tests for HIDTemperatureProvider sensor name parsing across chip generations

## v1.2.0

### Features

- Add `SignatureDetector` with explicit capture group mapping, dual-buffer distinct counting, cooldowns, stale cleanup, and LRU eviction
- Migrate P05 sandbox violation detection from rate counting to signature diversity with target normalization for temp paths, UUIDs, and numeric segments
- Add release helper script to package versioned DMGs and publish them to GitHub Releases via `gh`

## v1.1.1

### Bug Fixes

- Fix duplicate emoji in power state display (charging/plugged/battery labels showed emoji twice)
- Fix alert strings not updating on language switch — store `L10nKey` in config structs, resolve at emission time instead of detector construction time
- Fix hardcoded English in recovery alerts ("— Recovered", "system") — now uses L10n keys
- Expand `alertSleepDesc` to include assertion ID and type in description template
- Reduce AlertRow font sizes (title 14→11, body 12→10, timestamp 12→9) to match popover density

## v1.1.0

### Full i18n Support

- Add pure-Swift L10n engine with enum-based string table — no `.strings`/`.lproj` files needed
- Support English and Chinese (中文), defaulting to system language
- Localize all UI surfaces: popover views, settings tabs, status bar, context menu, pattern alerts, detector catalog
- Add language switcher in Settings (System / English / 中文)

### Appearance Mode

- Add light / dark / auto appearance mode preference in Settings
- Wire `NSApp.appearance` to persist and apply user choice at startup

### UI Polish

- Extract all colors, fonts, and layout constants into centralized `OwlTheme`
- Replace system colors with logo-derived `OwlPalette` (green, amber, red, purple)
- Fix popover first-open position jump via `preferredContentSize`
- Restore GeneralTab centered logo layout with stronger title treatment

## v1.0.0

Initial release — macOS menu bar system health monitor with 14 log-based pattern detectors, real-time metrics popover, and settings window.
