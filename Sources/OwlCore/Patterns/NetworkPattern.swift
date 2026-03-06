import Foundation

/// P12 — Network Connection Failure pattern configuration.
///
/// Detects system-wide network connection failures. Uses RateDetector
/// in global mode (no per-process grouping) since network issues are
/// typically system-level (DNS failure, VPN disconnect, etc.).
///
/// - Regex: matches nw_connection failure reports
/// - Window: 60 seconds
/// - Warning: 10 events/window (global)
/// - Critical: 30 events/window (global)
/// - Cooldown: 120 seconds
public enum NetworkPattern {

    public static let id = "network_failure"

    public static func makeDetector() -> RateDetector {
        RateDetector(config: RateConfig(
            id: id,
            regex: #"nw_connection.*reporting state failed error\s+(.+)"#,
            groupBy: .global,
            windowSeconds: 60,
            warningRate: 10,
            criticalRate: 30,
            cooldownInterval: 120,
            maxGroups: 1,
            title: "系统网络连接异常",
            descriptionTemplate: "过去 {window} 秒有 {count} 次网络连接失败",
            suggestion: "检查 WiFi 连接状态和 VPN 是否正常，尝试打开浏览器测试网络",
            acceptsFilter: "reporting state failed error"
        ))
    }
}
