import Foundation

/// P18 — Swap Usage pattern configuration.
///
/// Detects when swap usage exceeds thresholds for a sustained period.
/// Values are in bytes; thresholds are in GB converted to bytes.
///
/// - Warning: >4 GB for 30 seconds
/// - Critical: >8 GB for 30 seconds
/// - Recovery: ≤3 GB
public enum SwapUsagePattern {

    public static let id = "swap_usage"

    /// 1 GB in bytes.
    private static let gb: Double = 1_073_741_824

    public static func makeDetector() -> MetricsThresholdDetector {
        MetricsThresholdDetector(
            config: MetricsThresholdConfig(
                id: id,
                warningThreshold: 4 * gb,
                criticalThreshold: 8 * gb,
                recoveryThreshold: 3 * gb,
                sustainedDuration: 30,
                titleKey: .alertSwapUsageTitle,
                descriptionKey: { .alertSwapUsageDesc($0) },
                suggestionKey: .alertSwapUsageSuggestion,
                formatValue: {
                    String(format: "%.1f", $0 / gb)
                }
            ),
            extractor: { Double($0.extendedMemory.swapUsed) }
        )
    }
}
