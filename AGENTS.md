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
bash scripts/check-coverage.sh 90 # current line-only gate; full system1-quality target below
swift test --filter EndToEnd
bash scripts/build.sh --sign 'Apple Development: Your Name (TEAMID)'
```

## Testing and quality contract

Quality follows `system1-quality` (12 slots `S1..Z1` in `.github/workflows/quality-slots.yml`, `nocoo/base-ci v2026.15` for pinned actions). Statuses: `impl`, `na`, `manual`, or `planned`.

| Slot | Status | Implementation / Evidence |
| --- | --- | --- |
| S1: Typecheck | impl | `swift build` (plus Husky hook installation assertion in CI) |
| S2: Lint | impl | `swiftlint lint --strict` |
| S3: Workflow Lint | impl | `actionlint`, immutable `nocoo/base-ci` SHA check, and `yamllint` |
| G1: Secret Scan | impl | `gitleaks detect --no-banner --verbose --redact --config=.gitleaks.toml` |
| G2: Dependency Vulnerabilities | na | SwiftPM has no third-party dependencies; `package-lock.json` is Husky devDependency only |
| B1: Build | impl | `swift build -c release` |
| L1: Unit Tests & Coverage | impl | `OwlCoreTests` (excluding hardware/E2E suites) with coverage; local `check-coverage.sh 90` |
| L2: Runtime | na | Not a Cloudflare Worker project |
| L3: Integration | impl | `swift test --filter EndToEnd` (constructed logs through detectors/alerts) |
| L4: E2E | na (manual) | Native AppKit/SwiftUI menu-bar app; verified manually |
| P1: Package Check | na | Private package; SwiftPM executable not published to npm |
| Z1: Gate | impl | Aggregates all 11 slot outcomes and verifies `tested-sha` |

Husky sets `core.hooksPath` to `.husky/_` after `npm install` (`prepare`). `.husky/pre-commit` and `.husky/pre-push` delegate to `scripts/pre-commit.sh` and `scripts/pre-push.sh`. Legacy `.githooks/` symlinks to the same scripts remain for manual `core.hooksPath=.githooks` setups.

Pre-commit exports the staged index to a temporary tree, unsets Git hook environment, reuses a shared Clang module cache under `.build/owl-precommit-module-cache` (never symlinks the full `.build` tree), then runs L1 plus staged gitleaks. Pre-push runs EndToEnd integration tests (`L3`) and repository gitleaks (`G1`).
Never bypass commit/push hooks, force-push, or use autofix in checks. Documentation changes do not authorize deploying or implementing new gates.

## Resources and isolation

Use fresh preference suites, constructed logs and test-owned temporary paths. Hardware tests may read this Mac; never reset everyday preferences. Run native acceptance in a separate test app context.

## Operations / release

Use `scripts/build.sh` for signed app bundles. [DMG packaging](scripts/package-dmg.sh) and [notarization](scripts/notarize.sh) require separate release authorization. Do not change global credentials or claim notarization from a SwiftPM build.

## Retrospective

Move accident narratives to [Retrospective.md](Retrospective.md); keep at most about ten concise recurring project rules here. Put architecture and operational detail in linked docs.

- Convert Mach time and do not double-count live threads.
- Keep notifications safe in unbundled executables.
