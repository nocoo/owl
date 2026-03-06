import Foundation

/// P08 — Bluetooth Device Disconnect pattern configuration.
///
/// Detects Bluetooth devices repeatedly disconnecting by monitoring bluetoothd.
/// Uses RateDetector with capture group extraction of device MAC address.
///
/// - Regex: extracts MAC address from disconnect messages
/// - Window: 3600 seconds (1 hour)
/// - Warning: 3 events/window per device
/// - Critical: 8 events/window per device
/// - Cooldown: 300 seconds
public enum BluetoothPattern {

    public static let id = "bluetooth_disconnect"

    public static func makeDetector() -> RateDetector {
        RateDetector(config: RateConfig(
            id: id,
            regex: #"Device disconnected.*?\(([0-9A-Fa-f:]+)\)"#,
            groupBy: .captureGroup,
            windowSeconds: 3600,
            warningRate: 3,
            criticalRate: 8,
            cooldownInterval: 300,
            maxGroups: 20,
            title: "蓝牙设备反复断连",
            descriptionTemplate: "{key} 在过去 {window} 秒断连了 {count} 次",
            suggestion: "尝试重新配对设备，或检查设备电量是否不足",
            acceptsFilter: "Device disconnected"
        ))
    }
}
