# Owl

Local macOS menu-bar metrics, process inspection and anomaly alerts.
Profile: native-hybrid.
Direction: [architecture](docs/02-architecture.md). Frameworks must preserve this handbook.

## Scope and instruction sources

- This file is the only project handbook; nested files do not compete with it. Do not create a `CLAUDE.md` alias or copy.
- This file is the quality contract; hooks, CI and config are enforcement. Close implementation gaps without lowering the contract. Historical test results are not evidence of a current passing run.
- Human docs: [README.md](README.md) and [detection algorithms](docs/04-detection-algorithms.md). Native package: `Package.swift` (Swift tools 6.0, macOS 14+, Swift 5 language mode). Enforcement: `.husky/pre-commit` → `scripts/pre-commit.sh`, `.husky/pre-push` → `scripts/pre-push.sh`, `package.json` `prepare` (Husky), `.github/workflows/ci.yml`. Coverage/security: `scripts/check-coverage.sh`, `.swiftlint.yml`, `.gitleaks.toml`. Accidents: [Retrospective.md](Retrospective.md). Machine workflow: global `AGENTS.md` and Git rules.

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
| L1 Swift / Obj-C | planned | Pre-commit gates the Git index (`git checkout-index`), runs SwiftLint strict, unit tests with coverage and staged gitleaks; failures block commit. Installed via `npm install` / Husky. Line coverage floor remains 90% on scoped non-UI sources; four-metric ≥95%, compiler strict mode and Obj-C lint remain gaps. CI excludes EndToEnd and hardware suites. Probe: `npm run test:l1-gate`. |
| L2 native pipeline | enforced | Pre-push runs EndToEnd tests from constructed logs through detectors/alerts; these are in-process integration, not HTTP/UI tests. |
| L3 menu-bar / notifications | manual | Check menu-bar interactions, preferences and notifications in an app bundle; no native UI runner. |
| G2 | planned | Hooks and CI run gitleaks; CI disables dependency scanning. No third-party Swift packages are declared. |
| D1 | planned | Settings tests use fresh named UserDefaults suites; some tests read this Mac's sensors. Full isolated desktop/cleanup policy is not automated. |

Husky sets `core.hooksPath` to `.husky/_` after `npm install` (`prepare`). `.husky/pre-commit` and `.husky/pre-push` delegate to `scripts/pre-commit.sh` and `scripts/pre-push.sh`. Legacy `.githooks/` symlinks to the same scripts remain for manual `core.hooksPath=.githooks` setups.

Pre-commit exports the staged index to a temporary tree, unsets Git hook environment, optionally symlinks a warm `.build` when staged `Package.swift` matches the worktree, then runs unified L1 plus staged gitleaks. Any step failure exits nonzero and removes the snapshot on exit, interrupt or signal. Target wall time for ordinary commits is under 30s with a warm `.build`.

`scripts/check-coverage.sh` accepts either `.build/arm64-apple-macosx/debug/codecov/Owl.json` (legacy native backend path) or `.build/out/Products/Debug/codecov/Owl.json` (default `swift build` output). Four-metric ≥95% enforcement is still not implemented in the gate script.

Pre-push still runs on the working tree: EndToEnd integration tests and repository gitleaks. Target: stdin push-ref scope and parallel L2/G2 under 3 minutes remain future work. L3 runs in CI or an explicit manual lane.
Never bypass commit/push hooks, force-push, or use autofix in checks. Documentation changes do not authorize deploying or implementing new gates.

## Resources and isolation

Use fresh preference suites, constructed logs and test-owned temporary paths. Hardware tests may read this Mac; never reset everyday preferences. Run native acceptance in a separate test app context.

## Operations / release

Use `scripts/build.sh` for signed app bundles. [DMG packaging](scripts/package-dmg.sh) and [notarization](scripts/notarize.sh) require separate release authorization. Do not change global credentials or claim notarization from a SwiftPM build.

## Retrospective

Move accident narratives to [Retrospective.md](Retrospective.md); keep at most about ten concise recurring project rules here. Put architecture and operational detail in linked docs.

- Convert Mach time and do not double-count live threads.
- Keep notifications safe in unbundled executables.
