import Foundation

/// P07 — Process Crash Signal pattern configuration.
///
/// Detects services exiting due to fatal signals (SIGKILL, SIGSEGV, SIGABRT).
/// Uses RateDetector with capture group extraction of service name.
///
/// - Regex: extracts service name from "exited due to" messages
/// - Window: 3600 seconds (1 hour)
/// - Warning: 3 events/window per service
/// - Critical: 10 events/window per service
/// - Cooldown: 600 seconds
public enum CrashSignalPattern {

    public static let id = "process_crash_signal"

    public static func makeDetector() -> RateDetector {
        RateDetector(config: RateConfig(
            id: id,
            regex: #"Service\s+(\S+)\s+exited due to\s+SIG\w+"#,
            groupBy: .captureGroup,
            windowSeconds: 3600,
            warningRate: 3,
            criticalRate: 10,
            cooldownInterval: 600,
            maxGroups: 100,
            title: "进程频繁崩溃",
            descriptionTemplate: "{key} 在过去 {window} 秒因信号退出了 {count} 次",
            suggestion: "查看 ~/Library/Logs/DiagnosticReports/ 中对应的 crash 报告",
            acceptsFilter: "exited due to"
        ))
    }
}
