import Foundation

/// P10 — Jetsam Memory Kill pattern configuration.
///
/// Detects memory pressure kills by monitoring kernel Jetsam events.
/// Uses ThresholdDetector with zero debounce (any Jetsam kill is immediately
/// a warning). For critical escalation (3+ kills in 5 minutes), use a
/// companion RateDetector via `makeEscalationDetector()`.
///
/// Design: Two detectors work together:
/// - Primary (ThresholdDetector): Any single kill → immediate warning
/// - Escalation (RateDetector): 3+ kills in 5 min → critical
public enum JetsamPattern {

    public static let id = "jetsam_kill"
    public static let escalationID = "jetsam_kill_escalation"

    /// Primary detector: any single Jetsam kill triggers a warning.
    /// Uses ThresholdDetector with warningThreshold=0 and greaterThan so
    /// any positive value triggers immediately (debounce=0).
    public static func makeDetector() -> ThresholdDetector {
        ThresholdDetector(config: ThresholdConfig(
            id: id,
            regex: #"memorystatus_kill_top_process:.*pid\s+(\d+)"#,
            warningThreshold: 0,
            criticalThreshold: Double.greatestFiniteMagnitude,
            recoveryThreshold: -1,
            debounce: 0,
            comparison: .greaterThan,
            title: "系统内存不足",
            descriptionTemplate: "macOS 因内存压力终止了进程（PID {value}）",
            suggestion: "关闭不必要的应用以释放内存，或考虑重启系统",
            acceptsFilter: "memorystatus_kill_top_process"
        ))
    }

    /// Escalation detector: 3+ kills in 5 minutes → critical.
    public static func makeEscalationDetector() -> RateDetector {
        RateDetector(config: RateConfig(
            id: escalationID,
            regex: #"memorystatus_kill_top_process:.*\[(.+?)\]"#,
            groupBy: .global,
            windowSeconds: 300,
            warningRate: Int.max,
            criticalRate: 3,
            cooldownInterval: 60,
            maxGroups: 1,
            title: "系统内存严重不足",
            descriptionTemplate: "5 分钟内 {count} 个进程被 Jetsam 终止",
            suggestion: "关闭不必要的应用以释放内存，或考虑重启系统",
            acceptsFilter: "memorystatus_kill_top_process"
        ))
    }
}
