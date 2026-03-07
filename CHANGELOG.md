# Changelog

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
