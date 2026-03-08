import Foundation
import HIDThermalBridge

/// Reads CPU/GPU/SOC temperatures via IOHIDEventSystemClient on Apple Silicon.
/// Falls back gracefully to nil on Intel or when sensors are unavailable.
///
/// Unlike SMC `Tp*` keys which return sporadic garbage data on Apple Silicon,
/// the HID thermal sensors are maintained by IOHIDEventDriver at the kernel
/// level and provide stable, accurate readings directly from the ARM SoC's
/// built-in thermal monitoring hardware.
public final class HIDTemperatureProvider: Sendable {

    public init() {}

    /// Read CPU temperature (average of all CPU core sensors).
    /// Returns Celsius value or nil if unavailable.
    public func cpuTemperature() -> Double? {
        let sensors = cpuSensors()
        guard !sensors.isEmpty else { return nil }
        let sum = sensors.map(\.celsius).reduce(0, +)
        return sum / Double(sensors.count)
    }

    /// Read the hottest CPU core temperature.
    public func cpuTemperatureMax() -> Double? {
        cpuSensors().map(\.celsius).max()
    }

    /// Read all available HID thermal sensors.
    /// Returns array of (label, celsius) for sensors that responded.
    public func allTemperatures() -> [(String, Double)] {
        guard let dict = ReadHIDTemperatures() as? [String: Double] else {
            return []
        }
        return dict
            .sorted(by: { $0.key < $1.key })
            .map { ($0.key, $0.value) }
    }

    /// Returns true if HID thermal sensors are available (Apple Silicon).
    public func isAvailable() -> Bool {
        guard let dict = ReadHIDTemperatures() as? [String: Double] else {
            return false
        }
        return !dict.isEmpty
    }

    // MARK: - Internal helpers

    /// CPU sensor name prefixes.
    /// pACC = performance cores, eACC = efficiency cores.
    static let cpuPrefixes = ["pACC MTR Temp", "eACC MTR Temp"]

    /// GPU sensor name prefix.
    static let gpuPrefix = "GPU MTR Temp"

    /// Filter for CPU-only sensors from the raw dictionary.
    func cpuSensors() -> [(name: String, celsius: Double)] {
        guard let dict = ReadHIDTemperatures() as? [String: Double] else {
            return []
        }
        return dict
            .filter { entry in
                Self.cpuPrefixes.contains(where: { entry.key.hasPrefix($0) })
                    && entry.value > 0 && entry.value < 120
            }
            .map { (name: $0.key, celsius: $0.value) }
            .sorted(by: { $0.name < $1.name })
    }

    /// Read GPU temperature (average of all GPU core sensors).
    public func gpuTemperature() -> Double? {
        guard let dict = ReadHIDTemperatures() as? [String: Double] else {
            return nil
        }
        let gpuTemps = dict
            .filter { $0.key.hasPrefix(Self.gpuPrefix) && $0.value > 0 && $0.value < 120 }
            .map(\.value)
        guard !gpuTemps.isEmpty else { return nil }
        return gpuTemps.reduce(0, +) / Double(gpuTemps.count)
    }
}
