import Foundation

/// P17 — Memory Pressure pattern configuration.
///
/// Detects when system memory pressure (used/total %) exceeds thresholds
/// for a sustained period.
///
/// - Warning: >85% for 30 seconds
/// - Critical: >95% for 30 seconds
/// - Recovery: ≤80%
public enum MemoryPressurePattern {

    public static let id = "memory_pressure"

    public static func makeDetector() -> MetricsThresholdDetector {
        MetricsThresholdDetector(
            config: MetricsThresholdConfig(
                id: id,
                warningThreshold: 85,
                criticalThreshold: 95,
                recoveryThreshold: 80,
                sustainedDuration: 30,
                titleKey: .alertMemoryPressureTitle,
                descriptionKey: { .alertMemoryPressureDesc($0) },
                suggestionKey: .alertMemoryPressureSuggestion,
                formatValue: { String(format: "%.0f", $0) }
            ),
            extractor: { $0.memoryPressure }
        )
    }
}
