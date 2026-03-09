import Foundation
import HIDThermalBridge

/// Reads CPU/GPU/SOC temperatures via IOHIDEventSystemClient on Apple Silicon.
/// Falls back gracefully to nil on Intel or when sensors are unavailable.
///
/// Unlike SMC `Tp*` keys which return sporadic garbage data on Apple Silicon,
/// the HID thermal sensors are maintained by IOHIDEventDriver at the kernel
/// level and provide stable, accurate readings directly from the ARM SoC's
/// built-in thermal monitoring hardware.
///
/// Sensor naming varies by chip generation:
///   - M1/M2: `pACC MTR Temp SensorN`, `eACC MTR Temp SensorN`, `GPU MTR Temp SensorN`
///   - M3/M4: `PMU tdieN` (die temps), `PMU tdevN` (device temps)
public final class HIDTemperatureProvider: Sendable {

    public init() {}

    func sensorReadings() -> [String: Double] {
        ReadHIDTemperatures() as? [String: Double] ?? [:]
    }

    /// Read CPU die temperature (average of all die sensors).
    /// Returns Celsius value or nil if unavailable.
    public func cpuTemperature() -> Double? {
        Self.cpuTemperature(from: sensorReadings())
    }

    /// Read the hottest die sensor temperature.
    public func cpuTemperatureMax() -> Double? {
        Self.dieSensors(from: sensorReadings()).map(\.celsius).max()
    }

    /// Read all available HID thermal sensors.
    /// Returns array of (label, celsius) for sensors that responded.
    public func allTemperatures() -> [(String, Double)] {
        sensorReadings()
            .sorted(by: { $0.key < $1.key })
            .map { ($0.key, $0.value) }
    }

    /// Returns true if HID thermal sensors are available (Apple Silicon).
    public func isAvailable() -> Bool {
        !sensorReadings().isEmpty
    }

    // MARK: - Sensor name patterns

    /// Die temperature sensor patterns (CPU/GPU cores).
    /// M1/M2: pACC MTR Temp, eACC MTR Temp
    /// M3/M4: PMU tdie
    static let diePrefixes = [
        "pACC MTR Temp",
        "eACC MTR Temp",
        "PMU tdie"
    ]

    /// GPU sensor name prefixes.
    /// M1/M2: GPU MTR Temp
    /// M3/M4: GPU temperatures are included in PMU tdie sensors
    static let gpuPrefixes = [
        "GPU MTR Temp"
    ]

    /// Check if a sensor name matches any die temperature pattern.
    static func isDieSensor(_ name: String) -> Bool {
        diePrefixes.contains(where: { name.hasPrefix($0) })
    }

    static func dieSensors(
        from readings: [String: Double]
    ) -> [(name: String, celsius: Double)] {
        readings
            .filter { entry in
                Self.isDieSensor(entry.key)
                    && entry.value > 0 && entry.value < 120
            }
            .map { (name: $0.key, celsius: $0.value) }
            .sorted(by: { $0.name < $1.name })
    }

    static func cpuTemperature(
        from readings: [String: Double]
    ) -> Double? {
        let sensors = dieSensors(from: readings)
        guard !sensors.isEmpty else { return nil }
        let sum = sensors.map(\.celsius).reduce(0, +)
        return sum / Double(sensors.count)
    }

    /// Filter for die temperature sensors from the raw dictionary.
    func dieSensors() -> [(name: String, celsius: Double)] {
        Self.dieSensors(from: sensorReadings())
    }

    /// Read GPU temperature (average of GPU-specific sensors).
    /// On M3/M4, GPU die temps are part of the `PMU tdie` group
    /// and not separately identifiable, so this returns nil.
    /// Use `cpuTemperature()` which includes all die sensors.
    public func gpuTemperature() -> Double? {
        Self.gpuTemperature(from: sensorReadings())
    }

    static func gpuTemperature(
        from readings: [String: Double]
    ) -> Double? {
        let gpuTemps = readings
            .filter { entry in
                Self.gpuPrefixes.contains(where: { entry.key.hasPrefix($0) })
                    && entry.value > 0 && entry.value < 120
            }
            .map(\.value)
        guard !gpuTemps.isEmpty else { return nil }
        return gpuTemps.reduce(0, +) / Double(gpuTemps.count)
    }
}
