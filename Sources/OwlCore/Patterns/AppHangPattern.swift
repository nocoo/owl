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
            title: "应用无响应",
            descriptionTemplate: "PID {key} 未响应 WindowServer 的心跳检测（{count} 次/{window}s）",
            suggestion: "在 Activity Monitor 中查看该进程是否正常，可尝试强制退出",
            acceptsFilter: "failed to act on a ping"
        ))
    }
}
