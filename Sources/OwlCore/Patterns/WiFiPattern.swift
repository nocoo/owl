import Foundation

/// P04 — WiFi Signal Degradation pattern configuration.
///
/// Detects WiFi signal quality issues by monitoring RSSI values from airportd.
/// Uses ThresholdDetector with `.lessThan` comparison (lower RSSI = worse).
///
/// - Regex: extracts RSSI value in dBm (negative number)
/// - Warning: < -70 dBm
/// - Critical: < -80 dBm
/// - Recovery: >= -65 dBm (hysteresis)
/// - Debounce: 10 seconds (WiFi signals fluctuate)
public enum WiFiPattern {

    public static let id = "wifi_degradation"

    public static func makeDetector() -> ThresholdDetector {
        ThresholdDetector(config: ThresholdConfig(
            id: id,
            regex: #"LQM:.*rssi=([-\d]+)"#,
            warningThreshold: -70,
            criticalThreshold: -80,
            recoveryThreshold: -65,
            debounce: 10,
            comparison: .lessThan,
            title: L10n.tr(.alertWiFiTitle),
            descriptionTemplate: L10n.tr(.alertWiFiDesc("{value}")),
            suggestion: L10n.tr(.alertWiFiSuggestion),
            acceptsFilter: "LQM:"
        ))
    }
}
