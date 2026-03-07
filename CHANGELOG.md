# Changelog

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
