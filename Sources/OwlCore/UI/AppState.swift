import Foundation
import Observation

/// Observable application state that bridges the core engine to the UI layer.
///
/// Aggregates data from AlertStateManager and SystemMetricsPoller into
/// a single observable surface for SwiftUI views. Uses `@Observable`
/// (Swift 5.9+) for property-level tracking — only views that read a
/// specific property re-evaluate when that property changes.
///
/// Runs on @MainActor so all UI updates are safe.
@MainActor
@Observable
public final class AppState {

    public init() {}

    // MARK: - State

    /// Current aggregated severity (drives Menu Bar icon).
    public private(set) var currentSeverity: Severity = .normal

    /// Previous severity (used for recovery flash detection).
    public private(set) var previousSeverity: Severity?

    /// Active alerts sorted by severity (descending) then time (descending).
    public private(set) var activeAlerts: [Alert] = []

    /// Recent history (last N expired alerts).
    public private(set) var alertHistory: [Alert] = []

    /// Latest system metrics snapshot.
    public private(set) var metrics: SystemMetrics = .zero

    /// Network speed history for sparkline (last 30 samples).
    public private(set) var networkInHistory: [Double] = []
    public private(set) var networkOutHistory: [Double] = []

    private let maxNetworkSamples = 30

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
        guard metrics != newMetrics else { return }
        metrics = newMetrics

        // Append to network history for sparkline
        networkInHistory.append(newMetrics.network.bytesInPerSec)
        networkOutHistory.append(newMetrics.network.bytesOutPerSec)
        if networkInHistory.count > maxNetworkSamples {
            networkInHistory.removeFirst(
                networkInHistory.count - maxNetworkSamples
            )
        }
        if networkOutHistory.count > maxNetworkSamples {
            networkOutHistory.removeFirst(
                networkOutHistory.count - maxNetworkSamples
            )
        }
    }
}
