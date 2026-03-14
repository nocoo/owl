import Foundation

/// P16 — Thermal State detector.
///
/// Monitors `ProcessInfo.thermalState` and emits alerts on transitions:
/// - `.nominal` → no alert (or recovery if previously elevated)
/// - `.fair` / `.serious` → warning
/// - `.critical` → critical
///
/// Complementary to P01 (log-based thermal throttling from `setDetailedThermalPowerBudget`).
/// P01 detects kernel-level power budget changes; P16 detects the OS-level thermal state
/// that affects all applications.
public final class ThermalStateDetector: MetricsDetector {

    // MARK: - MetricsDetector conformance

    public let id: String
    public var isEnabled: Bool = true

    // MARK: - Configuration

    private let thermalStateProvider: @Sendable () -> ProcessInfo.ThermalState

    // MARK: - Runtime state

    private var previousState: ProcessInfo.ThermalState = .nominal

    public init(
        id: String,
        thermalStateProvider: @escaping @Sendable () -> ProcessInfo.ThermalState = {
            ProcessInfo.processInfo.thermalState
        }
    ) {
        self.id = id
        self.thermalStateProvider = thermalStateProvider
    }

    // MARK: - Processing

    public func process(_ metrics: SystemMetrics) -> Alert? {
        guard isEnabled else { return nil }

        let current = thermalStateProvider()
        defer { previousState = current }

        // No transition → no alert
        guard current != previousState else { return nil }

        switch current {
        case .nominal:
            // Recovery only if we were previously elevated
            if previousState != .nominal {
                return makeRecoveryAlert(timestamp: Date())
            }
            return nil

        case .fair, .serious:
            return makeAlert(
                severity: .warning,
                thermalState: current,
                timestamp: Date()
            )

        case .critical:
            return makeAlert(
                severity: .critical,
                thermalState: current,
                timestamp: Date()
            )

        @unknown default:
            return nil
        }
    }

    public func tick(at now: Date) -> [Alert] {
        // No time-based logic needed; transitions happen in process()
        []
    }

    // MARK: - Helpers

    private func makeAlert(
        severity: Severity,
        thermalState: ProcessInfo.ThermalState,
        timestamp: Date
    ) -> Alert {
        Alert(
            detectorID: id,
            severity: severity,
            title: L10n.tr(.alertThermalStateTitle),
            description: L10n.tr(.alertThermalStateDesc(
                thermalState.displayLabel
            )),
            suggestion: L10n.tr(.alertThermalStateSuggestion),
            timestamp: timestamp
        )
    }

    private func makeRecoveryAlert(timestamp: Date) -> Alert {
        let title = "\(L10n.tr(.alertThermalStateTitle)) — \(L10n.tr(.alertRecoveredSuffix))"
        return Alert(
            detectorID: id,
            severity: .info,
            title: title,
            description: L10n.tr(.alertRecoveredDesc),
            suggestion: "",
            timestamp: timestamp,
            ttl: 30
        )
    }
}

// MARK: - ThermalState Display

extension ProcessInfo.ThermalState {
    var displayLabel: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
