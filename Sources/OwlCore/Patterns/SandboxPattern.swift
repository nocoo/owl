import Foundation

/// P05 — Sandbox Violation Storm pattern configuration.
///
/// Detects applications generating excessive sandbox deny events.
/// Uses RateDetector with capture group extraction of process name.
///
/// - Regex: extracts process name from deny messages
/// - Window: 60 seconds
/// - Warning: 10 events/window per process
/// - Critical: 50 events/window per process
/// - Cooldown: 300 seconds
public enum SandboxPattern {

    public static let id = "sandbox_violation_storm"

    public static func makeDetector() -> RateDetector {
        RateDetector(config: RateConfig(
            id: id,
            regex: #"Sandbox:\s+(.+?)\(\d+\)\s+deny\(1\)"#,
            groupBy: .captureGroup,
            windowSeconds: 60,
            warningRate: 10,
            criticalRate: 50,
            cooldownInterval: 300,
            maxGroups: 50,
            title: L10n.tr(.alertSandboxTitle),
            descriptionTemplate: L10n.tr(.alertSandboxDesc("{key}", "{window}", "{count}")),
            suggestion: L10n.tr(.alertSandboxSuggestion),
            acceptsFilter: "deny(1)"
        ))
    }
}
