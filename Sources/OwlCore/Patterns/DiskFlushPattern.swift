import Foundation

/// P03 — APFS Flush Delay pattern configuration.
///
/// Detects disk I/O latency spikes by monitoring APFS transaction flush times.
/// Uses ThresholdDetector with `.greaterThan` comparison (higher latency = worse).
///
/// - Regex: extracts flush duration in milliseconds
/// - Warning: > 10 ms
/// - Critical: > 100 ms
/// - Recovery: <= 5 ms (hysteresis)
/// - Debounce: 3 seconds
public enum DiskFlushPattern {

    public static let id = "apfs_flush_delay"

    public static func makeDetector() -> ThresholdDetector {
        ThresholdDetector(config: ThresholdConfig(
            id: id,
            regex: #"tx_flush:\s*\d+\s+tx\s+in\s+([\d.]+)ms"#,
            warningThreshold: 10,
            criticalThreshold: 100,
            recoveryThreshold: 5,
            debounce: 3,
            comparison: .greaterThan,
            title: "磁盘 I/O 延迟升高",
            descriptionTemplate: "APFS 刷写耗时 {value} ms（正常 < 10 ms）",
            suggestion: "检查磁盘健康状态（Disk Utility → First Aid），确认没有大量写入操作",
            acceptsFilter: "tx_flush:"
        ))
    }
}
