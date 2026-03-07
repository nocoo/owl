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
            titleKey: .alertThermalTitle,
            descriptionTemplateKey: .alertThermalDesc("{value}"),
            suggestionKey: .alertThermalSuggestion,
            acceptsFilter: "setDetailedThermalPowerBudget"
        ))
    }
}
