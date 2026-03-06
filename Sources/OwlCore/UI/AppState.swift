import Foundation
import Combine

/// Observable application state that bridges the core engine to the UI layer.
///
/// Aggregates data from AlertStateManager and SystemMetricsPoller into
/// a single @Published surface for SwiftUI views. Runs on @MainActor
/// so all UI updates are safe.
@MainActor
public final class AppState: ObservableObject {

    // MARK: - Published State

    /// Current aggregated severity (drives Menu Bar icon).
    @Published public private(set) var currentSeverity: Severity = .normal

    /// Previous severity (used for recovery flash detection).
    @Published public private(set) var previousSeverity: Severity?

    /// Active alerts sorted by severity (descending) then time (descending).
    @Published public private(set) var activeAlerts: [Alert] = []

    /// Recent history (last N expired alerts).
    @Published public private(set) var alertHistory: [Alert] = []

    /// Latest system metrics snapshot.
    @Published public private(set) var metrics: SystemMetrics = .zero

    // MARK: - Alert Management

    /// Update alerts from AlertStateManager.
    public func updateAlerts(
        active: [Alert],
        history: [Alert],
        severity: Severity
    ) {
        let sorted = active.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity > rhs.severity
            }
            return lhs.timestamp > rhs.timestamp
        }
        previousSeverity = currentSeverity
        activeAlerts = sorted
        alertHistory = history
        currentSeverity = severity
    }

    /// Update system metrics from SystemMetricsPoller.
    public func updateMetrics(_ newMetrics: SystemMetrics) {
        metrics = newMetrics
    }
}
