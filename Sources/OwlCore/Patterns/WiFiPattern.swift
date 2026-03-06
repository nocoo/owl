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
            title: "WiFi 信号较弱",
            descriptionTemplate: "当前信号强度 {value} dBm",
            suggestion: "尝试靠近路由器，或切换到 5GHz 频段",
            acceptsFilter: "LQM:"
        ))
    }
}
