import Foundation

/// Category for grouping detectors in Settings UI.
public enum DetectorCategory: String, Sendable, CaseIterable {
    case hardware
    case memory
    case power
    case network
    case security
    case process

    public var displayName: String {
        switch self {
        case .hardware: return L10n.tr(.catHardware)
        case .memory: return L10n.tr(.catMemory)
        case .power: return L10n.tr(.catPower)
        case .network: return L10n.tr(.catNetwork)
        case .security: return L10n.tr(.catSecurity)
        case .process: return L10n.tr(.catProcess)
        }
    }

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

/// Provides display metadata for all 16 detectors (17 instances).
public enum DetectorCatalog {

    /// All detector info entries in display order (matches popover section order).
    public static var all: [DetectorInfo] {
        [
            // Hardware (CPU + Disk)
            DetectorInfo(
                id: "thermal_throttling",
                displayName: L10n.tr(.detectorThermalThrottling),
                description: L10n.tr(.detectorThermalThrottlingDesc),
                category: .hardware
            ),
            DetectorInfo(
                id: "sustained_high_cpu",
                displayName: L10n.tr(.detectorSustainedCPU),
                description: L10n.tr(.detectorSustainedCPUDesc),
                category: .hardware
            ),
            DetectorInfo(
                id: "thermal_state",
                displayName: L10n.tr(.detectorThermalState),
                description: L10n.tr(.detectorThermalStateDesc),
                category: .hardware
            ),
            DetectorInfo(
                id: "usb_device_error",
                displayName: L10n.tr(.detectorUSBDeviceError),
                description: L10n.tr(.detectorUSBDeviceErrorDesc),
                category: .hardware
            ),
            DetectorInfo(
                id: "apfs_flush_delay",
                displayName: L10n.tr(.detectorAPFSFlushDelay),
                description: L10n.tr(.detectorAPFSFlushDelayDesc),
                category: .hardware
            ),
            // Memory
            DetectorInfo(
                id: "jetsam_kill",
                displayName: L10n.tr(.detectorJetsamKill),
                description: L10n.tr(.detectorJetsamKillDesc),
                category: .memory
            ),
            DetectorInfo(
                id: "jetsam_kill_escalation",
                displayName: L10n.tr(.detectorJetsamEscalation),
                description: L10n.tr(.detectorJetsamEscalationDesc),
                category: .memory
            ),
            // Power
            DetectorInfo(
                id: "sleep_assertion_leak",
                displayName: L10n.tr(.detectorSleepAssertionLeak),
                description: L10n.tr(.detectorSleepAssertionLeakDesc),
                category: .power
            ),
            DetectorInfo(
                id: "darkwake_abnormal",
                displayName: L10n.tr(.detectorDarkWake),
                description: L10n.tr(.detectorDarkWakeDesc),
                category: .power
            ),
            // Network
            DetectorInfo(
                id: "wifi_degradation",
                displayName: L10n.tr(.detectorWiFiDegradation),
                description: L10n.tr(.detectorWiFiDegradationDesc),
                category: .network
            ),
            DetectorInfo(
                id: "bluetooth_disconnect",
                displayName: L10n.tr(.detectorBluetoothDisconnect),
                description: L10n.tr(.detectorBluetoothDisconnectDesc),
                category: .network
            ),
            DetectorInfo(
                id: "network_failure",
                displayName: L10n.tr(.detectorNetworkFailure),
                description: L10n.tr(.detectorNetworkFailureDesc),
                category: .network
            ),
            // Security
            DetectorInfo(
                id: "sandbox_violation_storm",
                displayName: L10n.tr(.detectorSandboxViolation),
                description: L10n.tr(.detectorSandboxViolationDesc),
                category: .security
            ),
            DetectorInfo(
                id: "tcc_permission_storm",
                displayName: L10n.tr(.detectorTCCPermissionStorm),
                description: L10n.tr(.detectorTCCPermissionStormDesc),
                category: .security
            ),
            // Process
            DetectorInfo(
                id: "process_crash_loop",
                displayName: L10n.tr(.detectorProcessCrashLoop),
                description: L10n.tr(.detectorProcessCrashLoopDesc),
                category: .process
            ),
            DetectorInfo(
                id: "process_crash_signal",
                displayName: L10n.tr(.detectorCrashSignal),
                description: L10n.tr(.detectorCrashSignalDesc),
                category: .process
            ),
            DetectorInfo(
                id: "app_hang",
                displayName: L10n.tr(.detectorAppHang),
                description: L10n.tr(.detectorAppHangDesc),
                category: .process
            ),
        ]
    }

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
