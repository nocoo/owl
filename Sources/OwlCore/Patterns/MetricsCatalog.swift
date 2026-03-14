import Foundation

/// Factory that creates all metrics-based detectors.
///
/// Use `makeAll()` to get a fresh array of metrics detectors for the pipeline.
/// Each call returns new instances so detector state is not shared.
public enum MetricsCatalog {

    /// Creates all metrics detectors. Returns 5 detector instances:
    /// - P15 SustainedCPUPattern (SustainedCPUDetector)
    /// - P16 ThermalStatePattern (ThermalStateDetector)
    /// - P17 MemoryPressurePattern (MetricsThresholdDetector)
    /// - P18 SwapUsagePattern (MetricsThresholdDetector)
    /// - P19 DiskUsagePattern (MetricsThresholdDetector)
    public static func makeAll() -> [MetricsDetector] {
        [
            SustainedCPUPattern.makeDetector(),
            ThermalStatePattern.makeDetector(),
            MemoryPressurePattern.makeDetector(),
            SwapUsagePattern.makeDetector(),
            DiskUsagePattern.makeDetector(),
        ]
    }
}
