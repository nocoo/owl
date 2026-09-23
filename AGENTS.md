# Owl

Local macOS menu-bar metrics, process inspection and anomaly alerts.
Profile: native-hybrid.
Direction: [architecture](docs/02-architecture.md). Frameworks must preserve this handbook.

## Scope and instruction sources

- This file is the only project handbook; nested files do not compete with it. Do not create a `CLAUDE.md` alias or copy.
- This file is the quality contract; hooks, CI and config are enforcement. Close implementation gaps without lowering the contract. Historical test results are not evidence of a current passing run.
- Human docs: [README.md](README.md) and [detection algorithms](docs/04-detection-algorithms.md). Native package: `Package.swift` (Swift tools 6.0, macOS 14+, Swift 5 language mode). Enforcement: `scripts/pre-commit.sh`, `scripts/pre-push.sh`, `.github/workflows/ci.yml`. Coverage/security: `scripts/check-coverage.sh`, `.swiftlint.yml`, `.gitleaks.toml`. Accidents: [Retrospective.md](Retrospective.md). Machine workflow: global `AGENTS.md` and Git rules.

## Project invariants

- Collect/analyze locally without accounts or external services; unavailable hardware metrics degrade honestly.
- Preferences use UserDefaults; recent alerts remain in process memory and are not restored after restart.
- Keep logic in OwlCore and the app shell thin; retain the Objective-C IOHID bridge for Apple Silicon temperatures.
- Convert `proc_taskinfo` Mach ticks using `mach_timebase_info`; total user/system already include live-thread time.
- Guard notification APIs when `Bundle.main.bundleIdentifier` is missing; unbundled SPM executables cannot use normal notifications.

## Setup and commands

UI/lifecycle in `Sources/Owl` (AppKit and SwiftUI); sampling/detectors in `Sources/OwlCore` (Unified Logging, IOKit, Mach/libproc); native bridge in `Sources/HIDThermalBridge` (Objective-C); tests in `Tests/OwlCoreTests` (Swift Testing, no third-party Swift package). Run at repository root on macOS 14+ with Swift 6/Xcode 16+. Installed hooks require SwiftLint and gitleaks; select full Xcode per command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and `XCODE_DEFAULT_TOOLCHAIN_OVERRIDE=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain` when SourceKit is unavailable under Command Line Tools. These per-command variables were required by SwiftLint during the 2026-09-23 validation; use them for normal commit/push hooks on the same setup. App bundling needs a valid local signing identity.

```bash
swift build
swift run Owl
swiftlint lint --strict
swift test --build-system native --enable-code-coverage --filter '^(?!.*EndToEnd).*$'
bash scripts/check-coverage.sh 90 # current line-only gate; full 6DQ target below
swift test --filter EndToEnd
bash scripts/build.sh --sign 'Apple Development: Your Name (TEAMID)'
```

## Testing and quality contract

6DQ keeps its name with unified L1, L2/L3, G2 and D1; the owner merged former G1 into L1 on 2026-09-21. Statuses: `enforced`, `planned`, `manual`, or `N/A`; partial enforcement below does not certify the full required bar.
Unified L1 requires statements, branches, functions and lines each ≥95%, with no skipped/focused tests; strict check-only types and lint/format with zero errors/warnings; installed hooks and failure rejection. Preserve any stricter package threshold. Native tools must identify unmeasured metrics as gaps.
G2 requires dependency and secret scans, with missing required scanners failing.

| Dimension | Status | Required proof and current evidence/gap |
|---|---|---|
| L1 Swift / Obj-C | planned | Hook checks non-UI line coverage at 90%; all four ≥95% metrics and bridge coverage remain gaps. Hooks/CI enforce SwiftLint strict, but strict compiler/format and Objective-C analysis are not established. CI excludes EndToEnd and hardware suites. |
| L2 native pipeline | enforced | Pre-push runs EndToEnd tests from constructed logs through detectors/alerts; these are in-process integration, not HTTP/UI tests. |
| L3 menu-bar / notifications | manual | Check menu-bar interactions, preferences and notifications in an app bundle; no native UI runner. |
| G2 | planned | Hooks and CI run gitleaks; CI disables dependency scanning. No third-party Swift packages are declared. |
| D1 | planned | Settings tests use fresh named UserDefaults suites; some tests read this Mac's sensors. Full isolated desktop/cleanup policy is not automated. |

Tracked `.githooks/` entrypoints link to `scripts/pre-commit.sh` and `scripts/pre-push.sh`. This checkout has executable `.git/hooks/pre-commit` and `.git/hooks/pre-push` links to those scripts; they run through Git's fallback even though `core.hooksPath` is unset. Pre-commit runs working-tree SwiftLint, unit tests, 90% line coverage and staged secret scanning; pre-push runs EndToEnd integration tests and history secrets. Neither uses the required index snapshot/stdin-ref scope.

The coverage script hardcodes `.build/arm64-apple-macosx/debug/codecov/Owl.json`; Swift 6.4 defaults to `swiftbuild` and emits `.build/out/Products/Debug/codecov/Owl.json`. Before committing on this toolchain, run the fresh native coverage command above on the current source; the supported but deprecated native backend supplies the legacy path. The ordinary hook still reruns unit tests through `swiftbuild` and reads that separate native report. Record both runs; backend-aware report discovery remains an enforcement gap.

Target hooks: pre-commit checks unified L1 against the index snapshot (`git checkout-index`) in <30s; pre-push checks L2 and G2 in parallel against every stdin push ref/commit in <3min, plus build where applicable. L3 runs in CI or an explicit manual lane.
Never bypass commit/push hooks, force-push, or use autofix in checks. Documentation changes do not authorize deploying or implementing new gates.

## Resources and isolation

Use fresh preference suites, constructed logs and test-owned temporary paths. Hardware tests may read this Mac; never reset everyday preferences. Run native acceptance in a separate test app context.

## Operations / release

Use `scripts/build.sh` for signed app bundles. [DMG packaging](scripts/package-dmg.sh) and [notarization](scripts/notarize.sh) require separate release authorization. Do not change global credentials or claim notarization from a SwiftPM build.

## Retrospective

Move accident narratives to [Retrospective.md](Retrospective.md); keep at most about ten concise recurring project rules here. Put architecture and operational detail in linked docs.

- Convert Mach time and do not double-count live threads.
- Keep notifications safe in unbundled executables.
