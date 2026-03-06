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
        return buildMetrics(from: desc)
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

    private func buildMetrics(
        from desc: [String: Any]
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
        let cycleCount = readCycleCount()
        let timeMinutes = readTimeRemaining()
        let temperature = readTemperature(from: desc)
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

    private func computeHealth(
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

    private func readTemperature(
        from desc: [String: Any]
    ) -> Double? {
        // IOPSCopyPowerSourcesInfo doesn't include Temperature on macOS.
        // Read directly from AppleSmartBattery IORegistry entry instead.
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            "Temperature" as CFString,
            kCFAllocatorDefault,
            0
        ) else { return nil }

        guard let raw = prop.takeRetainedValue() as? Int,
              raw > 0 else { return nil }
        // Value is in centidegrees Celsius
        return Double(raw) / 100.0
    }

    private func readCycleCount() -> Int {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != IO_OBJECT_NULL else { return 0 }
        defer { IOObjectRelease(service) }

        let prop = IORegistryEntryCreateCFProperty(
            service,
            "CycleCount" as CFString,
            kCFAllocatorDefault,
            0
        )
        return prop?.takeRetainedValue() as? Int ?? 0
    }
}
