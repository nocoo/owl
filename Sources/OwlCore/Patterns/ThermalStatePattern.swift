import Foundation

/// P16 — Thermal State pattern configuration.
///
/// Monitors macOS `ProcessInfo.thermalState` and alerts on transitions
/// to elevated thermal levels.
public enum ThermalStatePattern {

    public static let id = "thermal_state"

    public static func makeDetector(
        thermalStateProvider: @escaping @Sendable () -> ProcessInfo.ThermalState = {
            ProcessInfo.processInfo.thermalState
        }
    ) -> ThermalStateDetector {
        ThermalStateDetector(
            id: id,
            thermalStateProvider: thermalStateProvider
        )
    }
}
