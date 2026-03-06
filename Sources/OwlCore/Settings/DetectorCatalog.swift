import Foundation

/// Category for grouping detectors in Settings UI.
public enum DetectorCategory: String, Sendable, CaseIterable {
    case hardware = "Hardware"
    case process = "Process"
    case network = "Network"
    case security = "Security"
    case power = "Power"
    case memory = "Memory"

    public var symbolName: String {
        switch self {
        case .hardware: return "cpu"
        case .process: return "app.dashed"
        case .network: return "wifi"
        case .security: return "lock.shield"
        case .power: return "bolt"
        case .memory: return "memorychip"
        }
    }
}

/// Static metadata for a pattern detector, used in Settings UI.
public struct DetectorInfo: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let description: String
    public let category: DetectorCategory

    public init(
        id: String,
        displayName: String,
        description: String,
        category: DetectorCategory
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.category = category
    }
}

/// Provides display metadata for all 14 detectors (15 instances).
public enum DetectorCatalog {

    /// All detector info entries in display order.
    public static let all: [DetectorInfo] = [
        // Hardware
        DetectorInfo(
            id: "thermal_throttling",
            displayName: "Thermal Throttling",
            description: "CPU power budget reduction",
            category: .hardware
        ),
        DetectorInfo(
            id: "usb_device_error",
            displayName: "USB Device Error",
            description: "USB device transfer errors",
            category: .hardware
        ),
        // Process
        DetectorInfo(
            id: "process_crash_loop",
            displayName: "Process Crash Loop",
            description: "Repeated process crashes",
            category: .process
        ),
        DetectorInfo(
            id: "process_crash_signal",
            displayName: "Crash Signal",
            description: "SEGFAULT, SIGBUS, etc.",
            category: .process
        ),
        DetectorInfo(
            id: "app_hang",
            displayName: "App Hang",
            description: "Application unresponsive",
            category: .process
        ),
        // Network
        DetectorInfo(
            id: "wifi_degradation",
            displayName: "WiFi Degradation",
            description: "WiFi RSSI below threshold",
            category: .network
        ),
        DetectorInfo(
            id: "bluetooth_disconnect",
            displayName: "Bluetooth Disconnect",
            description: "Repeated disconnections",
            category: .network
        ),
        DetectorInfo(
            id: "network_failure",
            displayName: "Network Failure",
            description: "Connection failures",
            category: .network
        ),
        // Security
        DetectorInfo(
            id: "sandbox_violation_storm",
            displayName: "Sandbox Violation",
            description: "Access denial storm",
            category: .security
        ),
        DetectorInfo(
            id: "tcc_permission_storm",
            displayName: "TCC Permission Storm",
            description: "Privacy permission denials",
            category: .security
        ),
        // Power
        DetectorInfo(
            id: "sleep_assertion_leak",
            displayName: "Sleep Assertion Leak",
            description: "Unreleased sleep assertions",
            category: .power
        ),
        DetectorInfo(
            id: "darkwake_abnormal",
            displayName: "Dark Wake",
            description: "Excessive background wakes",
            category: .power
        ),
        // Memory
        DetectorInfo(
            id: "jetsam_kill",
            displayName: "Jetsam Memory Kill",
            description: "Process killed for memory",
            category: .memory
        ),
        DetectorInfo(
            id: "jetsam_kill_escalation",
            displayName: "Jetsam Escalation",
            description: "Rapid jetsam kills",
            category: .memory
        ),
        // Disk (put under Hardware)
        DetectorInfo(
            id: "apfs_flush_delay",
            displayName: "APFS Flush Delay",
            description: "Disk write flush too slow",
            category: .hardware
        )
    ]

    /// Detectors grouped by category, in category display order.
    public static var grouped: [(DetectorCategory, [DetectorInfo])] {
        DetectorCategory.allCases.compactMap { cat in
            let items = all.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    /// All detector IDs in display order.
    public static var allIDs: [String] {
        all.map(\.id)
    }

    /// Look up info by detector ID.
    public static func info(for id: String) -> DetectorInfo? {
        all.first { $0.id == id }
    }
}
