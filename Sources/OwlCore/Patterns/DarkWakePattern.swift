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
            title: "系统被频繁唤醒",
            descriptionTemplate: "过去 {window} 秒发生 {count} 次 DarkWake",
            suggestion: "运行 pmset -g log | grep DarkWake 查看详细唤醒记录",
            acceptsFilter: "DarkWake"
        ))
    }
}
