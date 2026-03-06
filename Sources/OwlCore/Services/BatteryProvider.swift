import Foundation
import IOKit.ps

/// Reads battery info via IOKit power sources.
public struct BatteryProvider: Sendable {
    public init() {}

    /// Returns battery metrics, or .unavailable on desktops.
    public func batteryInfo() -> BatteryMetrics {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?
            .takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(snapshot)?
                .takeRetainedValue() as? [CFTypeRef],
            let first = sources.first,
            let desc = IOPSGetPowerSourceDescription(
                snapshot, first
            )?.takeUnretainedValue() as? [String: Any]
        else {
            return .unavailable
        }

        let level = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCap = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let designCap = desc[kIOPSDesignCapacityKey] as? Int
        let isCharging = desc[kIOPSIsChargingKey] as? Bool
            ?? false
        let source = desc[kIOPSPowerSourceStateKey] as? String
        let isPluggedIn = source == kIOPSACPowerValue

        // Health: maxCapacity / designCapacity
        let health: Double
        if let design = designCap, design > 0 {
            health = Double(maxCap) / Double(design) * 100
        } else {
            health = 100
        }

        // Cycle count from IOKit registry
        let cycleCount = readCycleCount()

        // Time remaining
        let timeRem = IOPSGetTimeRemainingEstimate()
        let timeMinutes: Int?
        if timeRem == kIOPSTimeRemainingUnlimited {
            timeMinutes = nil // plugged in
        } else if timeRem == kIOPSTimeRemainingUnknown {
            timeMinutes = nil
        } else {
            timeMinutes = Int(timeRem / 60)
        }

        // Temperature from battery properties
        let tempRaw = desc["Temperature"] as? Int
        let temperature: Double?
        if let raw = tempRaw {
            temperature = Double(raw) / 100.0
        } else {
            temperature = nil
        }

        // Condition
        let condition = desc["BatteryHealthCondition"]
            as? String ?? "Normal"

        return BatteryMetrics(
            level: Double(level),
            health: min(health, 100),
            cycleCount: cycleCount,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            temperature: temperature,
            timeRemaining: timeMinutes,
            condition: condition
        )
    }

    private func readCycleCount() -> Int {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != IO_OBJECT_NULL else { return 0 }
        defer { IOObjectRelease(service) }

        let prop = IORegistryEntryCreateCFProperty(
            service, "CycleCount" as CFString,
            kCFAllocatorDefault, 0
        )
        return prop?.takeRetainedValue() as? Int ?? 0
    }
}
