# Owl

Local macOS menu-bar metrics, process inspection, and anomaly alerts (`Package.swift`: Swift tools 6.0, macOS 14+, Swift 5 language mode).
Docs: [README.md](README.md) · [Architecture](docs/02-architecture.md) · [Detection Algorithms](docs/04-detection-algorithms.md) · [Distribution](docs/06-distribution.md) · [Retrospective](Retrospective.md)

## Commands

Layout: `Sources/Owl` (thin AppKit/SwiftUI shell), `Sources/OwlCore` (Unified Logging, IOKit, Mach/libproc), `Sources/HIDThermalBridge` (Objective-C IOHID bridge), `Tests/OwlCoreTests` (Swift Testing, zero third-party Swift packages). Run from root on macOS 14+ with Swift 6 / Xcode 16+; local hooks require `swiftlint`, `gitleaks`, and `jq`. When SourceKit is unavailable under Command Line Tools, prefix commands (including commit/push hooks) with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer XCODE_DEFAULT_TOOLCHAIN_OVERRIDE=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain`. App bundling needs a valid local signing identity.

```sh
npm install                                      # installs Husky hooks via prepare
swift build                                      # S1
swift run Owl                                    # unbundled local run
swiftlint lint --strict                          # S2 (0 warnings, .swiftlint.yml)
swift test --build-system native --enable-code-coverage --filter '^(?!.*EndToEnd).*$' # L1
bash scripts/check-coverage.sh 90                # L1 line-coverage gate
swift test --filter EndToEnd                     # L3
gitleaks detect --no-banner --verbose --redact --config=.gitleaks.toml # G1
swift build -c release                           # B1
bash scripts/build.sh --sign 'Apple Development: Your Name (TEAMID)'   # signed Owl.app
```

## Invariants

- Collect and analyze strictly locally with no accounts or external services; unavailable hardware metrics degrade honestly.
- Preferences persist in `UserDefaults`; recent alerts stay in process memory and are not restored after restart.
- Keep business logic in `OwlCore` and the `Sources/Owl` app shell thin; retain the Objective-C `HIDThermalBridge` for Apple Silicon temperatures.
- Convert `proc_taskinfo` Mach ticks via `mach_timebase_info`; `pti_total_user`/`pti_total_system` already include live-thread time (never add `pti_threads_*`).
- Guard all `UNUserNotificationCenter` calls when `Bundle.main.bundleIdentifier` is nil; unbundled SwiftPM executables crash without a bundle proxy.
- Signed bundles use `scripts/build.sh`; [DMG packaging](scripts/package-dmg.sh) and [notarization](scripts/notarize.sh) require separate release authorization.
- Never alter global credentials, claim notarization from an SPM build, bypass hooks, or run autofix in checks; historical test results are not evidence of a current passing run.

## Quality & Local Gates

Follows `system1-quality`; macOS native CI slots and `nocoo/base-ci` scanner pin live in `.github/workflows/quality-slots.yml` (invoked by `.github/workflows/ci.yml`; `quality / Z1: Gate` required on `main`). Status vocabulary: `enforced`, `planned`, `manual`, `N/A`.

- **Exceptions**: `G2` is `N/A` (no third-party SwiftPM deps; Husky dev-only lockfile), `L2` is `N/A` (not a Worker), `P1` is `N/A` (private executable), and `L4 E2E` is `manual` (native menu-bar UI).
- **L1 boundary**: CI skips `EndToEnd` and hardware suites; local `check-coverage.sh 90` checks 90% lines excluding `UI/`, `Tests/`, `L10n.swift`, `OwlApp*.swift` (95% 4-metric target `planned`).
- **Local hooks**: `npm install` (`prepare`) sets `core.hooksPath=.husky/_`; `.husky/*` and legacy `.githooks/*` delegate to `scripts/pre-commit.sh` and `scripts/pre-push.sh`.
- **Pre-commit**: checks staged `gitleaks` (`G1`), exports staged index with hook env unset, shares `.build/owl-precommit-module-cache` (never symlink `.build`), then runs `S2` + `L1` (`90%` lines).
- **Pre-push & discipline**: pre-push runs `EndToEnd` (`L3`) and repo `gitleaks` (`G1`). Close gaps without lowering the contract; docs changes do not authorize releases or new gates.

## Resources & Isolation

| Lane | State / Context | Boundary |
| --- | --- | --- |
| Daily app | `UserDefaults` (`com.nocoo.owl`), in-memory alerts | Preserve everyday preferences; never reset during tests |
| Automated tests | Fresh preference suites, constructed logs, temp dirs | Test-owned paths only; hardware tests may read this Mac only |
| Native acceptance | Separate test app context (`Owl.app`) | Signed via `scripts/build.sh`; DMG/notarization needs authorization |

## Retrospective

Record incident narratives in [Retrospective.md](Retrospective.md); promote recurring project constraints to `Invariants` above and enforceable safeguards to tests/hooks.
