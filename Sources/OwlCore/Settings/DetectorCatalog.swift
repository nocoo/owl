import Foundation

/// Static metadata for a pattern detector, used in Settings UI.
public struct DetectorInfo: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String

    public init(
        id: String,
        displayName: String,
        description: String
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
    }
}

/// Provides display metadata for all 14 detectors (15 instances).
public enum DetectorCatalog {

    /// All detector info entries in display order.
    public static let all: [DetectorInfo] = [
        DetectorInfo(
            id: "thermal_throttling",
            displayName: "Thermal Throttling",
            description: "CPU power budget reduction due to heat"
        ),
        DetectorInfo(
            id: "process_crash_loop",
            displayName: "Process Crash Loop",
            description: "Repeated process crashes within a window"
        ),
        DetectorInfo(
            id: "apfs_flush_delay",
            displayName: "APFS Flush Delay",
            description: "Disk write flush taking too long"
        ),
        DetectorInfo(
            id: "wifi_degradation",
            displayName: "WiFi Signal Degradation",
            description: "WiFi RSSI dropping below threshold"
        ),
        DetectorInfo(
            id: "sandbox_violation_storm",
            displayName: "Sandbox Violation Storm",
            description: "App sandbox access denial storm"
        ),
        DetectorInfo(
            id: "sleep_assertion_leak",
            displayName: "Sleep Assertion Leak",
            description: "Unreleased sleep prevention assertions"
        ),
        DetectorInfo(
            id: "process_crash_signal",
            displayName: "Crash Signal",
            description: "Fatal signals (SEGFAULT, SIGBUS, etc.)"
        ),
        DetectorInfo(
            id: "bluetooth_disconnect",
            displayName: "Bluetooth Disconnect",
            description: "Repeated Bluetooth device disconnections"
        ),
        DetectorInfo(
            id: "tcc_permission_storm",
            displayName: "TCC Permission Storm",
            description: "Privacy permission denial storm"
        ),
        DetectorInfo(
            id: "jetsam_kill",
            displayName: "Jetsam Memory Kill",
            description: "System killing processes due to memory"
        ),
        DetectorInfo(
            id: "jetsam_kill_escalation",
            displayName: "Jetsam Escalation",
            description: "Rapid jetsam kills indicating memory crisis"
        ),
        DetectorInfo(
            id: "app_hang",
            displayName: "App Hang",
            description: "Application becoming unresponsive"
        ),
        DetectorInfo(
            id: "network_failure",
            displayName: "Network Failure",
            description: "Network connection failures"
        ),
        DetectorInfo(
            id: "usb_device_error",
            displayName: "USB Device Error",
            description: "USB device transfer errors"
        ),
        DetectorInfo(
            id: "darkwake_abnormal",
            displayName: "Dark Wake",
            description: "Excessive background wake events"
        )
    ]

    /// All detector IDs in display order.
    public static var allIDs: [String] {
        all.map(\.id)
    }

    /// Look up info by detector ID.
    public static func info(for id: String) -> DetectorInfo? {
        all.first { $0.id == id }
    }
}
