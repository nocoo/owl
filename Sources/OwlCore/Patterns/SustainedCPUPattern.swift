import Foundation

/// P15 — Sustained High CPU pattern configuration.
///
/// Detects when system-wide CPU usage exceeds 80% for more than 60 seconds.
/// Escalates to critical when combined with thermal pressure.
public enum SustainedCPUPattern {

    public static let id = "sustained_high_cpu"

    public static func makeDetector(
        thermalStateProvider: @escaping @Sendable () -> ProcessInfo.ThermalState = {
            ProcessInfo.processInfo.thermalState
        }
    ) -> SustainedCPUDetector {
        SustainedCPUDetector(
            config: SustainedCPUConfig(
                id: id,
                threshold: 80,
                duration: 60
            ),
            thermalStateProvider: thermalStateProvider
        )
    }
}
