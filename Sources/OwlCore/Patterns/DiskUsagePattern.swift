import Foundation

/// P19 — Disk Usage pattern configuration.
///
/// Detects when root volume disk usage exceeds thresholds for a sustained
/// period.
///
/// - Warning: >85% for 60 seconds
/// - Critical: >95% for 60 seconds
/// - Recovery: ≤80%
public enum DiskUsagePattern {

    public static let id = "disk_usage"

    public static func makeDetector() -> MetricsThresholdDetector {
        MetricsThresholdDetector(
            config: MetricsThresholdConfig(
                id: id,
                warningThreshold: 85,
                criticalThreshold: 95,
                recoveryThreshold: 80,
                sustainedDuration: 60,
                titleKey: .alertDiskUsageTitle,
                descriptionKey: { .alertDiskUsageDesc($0) },
                suggestionKey: .alertDiskUsageSuggestion,
                formatValue: { String(format: "%.0f", $0) }
            ),
            extractor: { $0.disk.usedPercent }
        )
    }
}
