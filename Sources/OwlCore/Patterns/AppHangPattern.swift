import Foundation

/// P11 — App Hang pattern configuration.
///
/// Detects unresponsive applications by monitoring WindowServer ping failures.
/// Uses RateDetector with capture group extraction of PID.
///
/// - Regex: extracts PID from "failed to act on a ping" messages
/// - Window: 60 seconds
/// - Warning: 2 events/window per PID
/// - Critical: none (warning only)
/// - Cooldown: 120 seconds
public enum AppHangPattern {

    public static let id = "app_hang"

    public static func makeDetector() -> RateDetector {
        RateDetector(config: RateConfig(
            id: id,
            regex: #"\[pid=(\d+)\]\s+failed to act on a ping"#,
            groupBy: .captureGroup,
            windowSeconds: 60,
            warningRate: 2,
            criticalRate: Int.max,
            cooldownInterval: 120,
            maxGroups: 50,
            title: L10n.tr(.alertAppHangTitle),
            descriptionTemplate: L10n.tr(.alertAppHangDesc("{key}", "{count}", "{window}")),
            suggestion: L10n.tr(.alertAppHangSuggestion),
            acceptsFilter: "failed to act on a ping"
        ))
    }
}
