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
            title: "沙箱违规风暴",
            descriptionTemplate: "{key} 在过去 {window} 秒被拒绝 {count} 次",
            suggestion: "通常为应用兼容性问题，如频繁发生可尝试重装该应用或检查权限设置",
            acceptsFilter: "deny(1)"
        ))
    }
}
