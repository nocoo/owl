import Foundation
import IOKit.ps

/// Reads battery info via IOKit power sources.
public struct BatteryProvider: Sendable {
    public init() {}

    /// Returns battery metrics, or .unavailable on desktops.
    public func batteryInfo() -> BatteryMetrics {
        guard let desc = powerSourceDescription() else {
            return .unavailable
        }
        return Self.buildMetrics(
            description: desc,
            batteryProperties: smartBatteryProperties(),
            timeRemaining: readTimeRemaining()
        )
    }

    private func powerSourceDescription()
        -> [String: Any]? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?
            .takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(snapshot)?
                .takeRetainedValue() as? [CFTypeRef],
            let first = sources.first
        else { return nil }

        return IOPSGetPowerSourceDescription(
            snapshot, first
        )?.takeUnretainedValue() as? [String: Any]
    }

    private func smartBatteryProperties()
        -> [String: Any] {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != IO_OBJECT_NULL else { return [:] }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(
            service, &props, kCFAllocatorDefault, 0
        )
        guard result == kIOReturnSuccess else { return [:] }
        return props?.takeRetainedValue() as? [String: Any] ?? [:]
    }

    static func buildMetrics(
        description desc: [String: Any],
        batteryProperties: [String: Any],
        timeRemaining: Int?
    ) -> BatteryMetrics {
        let level = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCap = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let designCap = desc[kIOPSDesignCapacityKey] as? Int
        let isCharging = desc[kIOPSIsChargingKey] as? Bool
            ?? false
        let source = desc[kIOPSPowerSourceStateKey] as? String
        let isPluggedIn = source == kIOPSACPowerValue

        let health = computeHealth(
            maxCap: maxCap, designCap: designCap
        )
        let cycleCount = cycleCount(
            from: batteryProperties
        )
        let temperature = temperature(
            from: batteryProperties
        )
        let rawCondition = desc["BatteryHealthCondition"]
            as? String ?? ""
        let condition = rawCondition.isEmpty ? "Normal" : rawCondition

        return BatteryMetrics(
            level: Double(level),
            health: min(health, 100),
            cycleCount: cycleCount,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            temperature: temperature,
            timeRemaining: timeRemaining,
            condition: condition,
            wattage: wattage(from: batteryProperties)
        )
    }

    private static func computeHealth(
        maxCap: Int, designCap: Int?
    ) -> Double {
        if let design = designCap, design > 0 {
            return Double(maxCap) / Double(design) * 100
        }
        return 100
    }

    private func readTimeRemaining() -> Int? {
        let timeRem = IOPSGetTimeRemainingEstimate()
        if timeRem == kIOPSTimeRemainingUnlimited {
            return nil
        } else if timeRem == kIOPSTimeRemainingUnknown {
            return nil
        }
        return Int(timeRem / 60)
    }

    static func temperature(
        from batteryProperties: [String: Any]
    ) -> Double? {
        guard let raw = batteryProperties["Temperature"] as? Int,
              raw > 0 else { return nil }
        // Value is in centidegrees Celsius
        return Double(raw) / 100.0
    }

    static func cycleCount(
        from batteryProperties: [String: Any]
    ) -> Int {
        batteryProperties["CycleCount"] as? Int ?? 0
    }

    /// Read instantaneous power in watts from AppleSmartBattery.
    /// Voltage (mV) × Amperage (mA) / 1_000_000 = Watts.
    /// Amperage is negative when discharging; we return abs value.
    static func wattage(
        from batteryProperties: [String: Any]
    ) -> Double? {
        guard let mV = batteryProperties["Voltage"] as? Int,
              let mA = batteryProperties["Amperage"] as? Int,
              mV > 0
        else { return nil }

        return abs(Double(mV) * Double(mA)) / 1_000_000
    }
}
