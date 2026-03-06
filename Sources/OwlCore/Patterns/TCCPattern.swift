import Foundation

/// P09 — TCC Permission Storm pattern configuration.
///
/// Detects applications generating excessive permission denials.
/// Uses RateDetector with capture group extraction of bundle ID.
///
/// - Regex: extracts bundleID from AUTHREQ_RESULT DENIED messages
/// - Window: 60 seconds
/// - Warning: 10 events/window per app
/// - Critical: 30 events/window per app
/// - Cooldown: 300 seconds
public enum TCCPattern {

    public static let id = "tcc_permission_storm"

    public static func makeDetector() -> RateDetector {
        RateDetector(config: RateConfig(
            id: id,
            regex: #"AUTHREQ_RESULT:\s*DENIED.*bundleID=(\S+?)[\s,]"#,
            groupBy: .captureGroup,
            windowSeconds: 60,
            warningRate: 10,
            criticalRate: 30,
            cooldownInterval: 300,
            maxGroups: 50,
            title: "权限请求被大量拒绝",
            descriptionTemplate: "{key} 在过去 {window} 秒请求权限被拒绝 {count} 次",
            suggestion: "在系统设置 → 隐私与安全中检查该应用的权限配置",
            acceptsFilter: "AUTHREQ_RESULT:"
        ))
    }
}
