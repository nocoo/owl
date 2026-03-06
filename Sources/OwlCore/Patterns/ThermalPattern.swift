import Foundation

/// P01 — Thermal Throttling pattern configuration.
///
/// Detects CPU thermal throttling by monitoring the kernel power budget.
/// Uses ThresholdDetector with `.lessThan` comparison (lower budget = worse).
///
/// - Regex: extracts current power budget in mW
/// - Warning: < 6000 mW
/// - Critical: < 3000 mW
/// - Recovery: >= 7000 mW (hysteresis)
/// - Debounce: 5 seconds
public enum ThermalPattern {

    public static let id = "thermal_throttling"

    public static func makeDetector() -> ThresholdDetector {
        ThresholdDetector(config: ThresholdConfig(
            id: id,
            regex: #"current power budget:\s*(\d+)"#,
            warningThreshold: 6000,
            criticalThreshold: 3000,
            recoveryThreshold: 7000,
            debounce: 5,
            comparison: .lessThan,
            title: "CPU 散热节流中",
            descriptionTemplate: "当前功率预算 {value} mW，系统正在降频散热",
            suggestion: "检查是否有高 CPU 进程（Activity Monitor），确保通风口畅通",
            acceptsFilter: "setDetailedThermalPowerBudget"
        ))
    }
}
