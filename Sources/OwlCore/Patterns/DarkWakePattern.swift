import Foundation

/// P14 — DarkWake Abnormal Wakeup pattern configuration.
///
/// Detects excessive system wakeups during sleep by monitoring DarkWake events.
/// Uses RateDetector in global mode (counts total frequency regardless of cause).
///
/// - Regex: matches DarkWake from Sleep messages
/// - Window: 3600 seconds (1 hour)
/// - Warning: 10 events/window (global)
/// - Critical: 30 events/window (global)
/// - Cooldown: 600 seconds
public enum DarkWakePattern {

    public static let id = "darkwake_abnormal"

    public static func makeDetector() -> RateDetector {
        RateDetector(config: RateConfig(
            id: id,
            regex: #"DarkWake\s+from\s+\w+\s+Sleep"#,
            groupBy: .global,
            windowSeconds: 3600,
            warningRate: 10,
            criticalRate: 30,
            cooldownInterval: 600,
            maxGroups: 1,
            title: L10n.tr(.alertDarkWakeTitle),
            descriptionTemplate: L10n.tr(.alertDarkWakeDesc("{window}", "{count}")),
            suggestion: L10n.tr(.alertDarkWakeSuggestion),
            acceptsFilter: "DarkWake"
        ))
    }
}
