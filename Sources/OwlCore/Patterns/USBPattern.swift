import Foundation

/// P13 — USB Device Error pattern configuration.
///
/// Detects USB device communication errors by monitoring IOUSBHostPipe aborts.
/// Uses RateDetector with capture group extraction of device ID.
///
/// - Regex: extracts device identifier from abortGated messages
/// - Window: 3600 seconds (1 hour)
/// - Warning: 5 events/window per device
/// - Critical: 20 events/window per device
/// - Cooldown: 600 seconds
public enum USBPattern {

    public static let id = "usb_device_error"

    public static func makeDetector() -> RateDetector {
        RateDetector(config: RateConfig(
            id: id,
            regex: #"IOUSBHostPipe::abortGated:.*device\s+(0x[0-9a-fA-F]+)"#,
            groupBy: .captureGroup,
            windowSeconds: 3600,
            warningRate: 5,
            criticalRate: 20,
            cooldownInterval: 600,
            maxGroups: 20,
            titleKey: .alertUSBTitle,
            descriptionTemplateKey: .alertUSBDesc("{key}", "{window}", "{count}"),
            suggestionKey: .alertUSBSuggestion,
            acceptsFilter: "IOUSBHostPipe::abortGated"
        ))
    }
}
