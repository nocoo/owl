import Foundation

/// Manages alert lifecycle: pending → active → expired → history.
///
/// Alerts from the pipeline are first placed in a pending queue with a debounce
/// window. If the alert persists past debounce, it becomes active and is shown
/// in the UI. Active alerts expire after their TTL and move to history.
///
/// When the same detector produces a new alert:
/// - Higher severity → upgrade the existing alert
/// - Same severity → refresh the TTL (keep the newer timestamp)
/// - Lower severity → ignore (keep the existing higher severity)
///
/// `currentSeverity` is always the max severity of all active alerts, or `.normal`
/// if no alerts are active. This drives the Menu Bar icon state.
@MainActor
public final class AlertStateManager {

    /// Alerts waiting to be confirmed (within debounce window).
    public private(set) var pendingAlerts: [Alert] = []

    /// Confirmed active alerts being displayed.
    public private(set) var activeAlerts: [Alert] = []

    /// Recently expired alerts for the history view.
    public private(set) var alertHistory: [Alert] = []

    /// Called when an alert is newly activated (promoted from pending) or
    /// upgraded to a higher severity. Same-severity TTL refreshes do NOT
    /// trigger this callback.
    public var onAlertActivated: ((Alert) -> Void)?

    /// The highest severity among all active alerts.
    public var currentSeverity: Severity {
        activeAlerts.map(\.severity).max() ?? .normal
    }

    private let debounceInterval: TimeInterval
    private let maxHistory: Int

    /// Timestamps when pending alerts were received (keyed by index-matched position).
    private var pendingReceivedAt: [Date] = []

    /// Creates an AlertStateManager.
    /// - Parameters:
    ///   - debounceInterval: Seconds an alert must persist before becoming active (default 5s).
    ///   - maxHistory: Maximum number of expired alerts to keep in history (default 50).
    public init(debounceInterval: TimeInterval = 5, maxHistory: Int = 50) {
        self.debounceInterval = debounceInterval
        self.maxHistory = maxHistory
    }

    // MARK: - Receiving Alerts

    /// Receives a new alert from the pipeline.
    ///
    /// If the same detector already has an active alert:
    /// - Higher severity → upgrade immediately (bypass debounce)
    /// - Same severity → refresh TTL immediately
    /// - Lower severity → ignore
    ///
    /// Otherwise, the alert enters the pending queue.
    public func receive(_ alert: Alert) {
        // Check if this detector already has an active alert
        if let existingIndex = activeAlerts.firstIndex(
            where: { $0.detectorID == alert.detectorID }
        ) {
            let existing = activeAlerts[existingIndex]
            if alert.severity > existing.severity {
                // Upgrade: replace with higher severity
                activeAlerts[existingIndex] = alert
                onAlertActivated?(alert)
            } else if alert.severity == existing.severity {
                // Refresh: keep severity, update timestamp/TTL
                activeAlerts[existingIndex] = alert
            }
            // Lower severity: ignore
            return
        }

        // Check if this detector already has a pending alert
        if let pendingIndex = pendingAlerts.firstIndex(
            where: { $0.detectorID == alert.detectorID }
        ) {
            let existing = pendingAlerts[pendingIndex]
            if alert.severity >= existing.severity {
                pendingAlerts[pendingIndex] = alert
                // Keep original received-at time for debounce
            }
            return
        }

        // New alert → add to pending
        pendingAlerts.append(alert)
        pendingReceivedAt.append(alert.timestamp)
    }

    // MARK: - Maintenance

    /// Performs periodic maintenance: promote pending, expire active, clean history.
    /// Call this at the pipeline's tick interval.
    public func performMaintenance(at now: Date) {
        promotePending(at: now)
        expireActive(at: now)
        expirePending(at: now)
    }

    // MARK: - Private

    /// Promotes pending alerts that have passed the debounce window.
    private func promotePending(at now: Date) {
        var indicesToRemove: [Int] = []

        for (index, alert) in pendingAlerts.enumerated() {
            let receivedAt = pendingReceivedAt[index]
            if now.timeIntervalSince(receivedAt) >= debounceInterval {
                // Check if detector already has active alert (could have been
                // added by an upgrade while this was pending)
                if let existingIndex = activeAlerts.firstIndex(
                    where: { $0.detectorID == alert.detectorID }
                ) {
                    if alert.severity > activeAlerts[existingIndex].severity {
                        activeAlerts[existingIndex] = alert
                        onAlertActivated?(alert)
                    }
                } else {
                    activeAlerts.append(alert)
                    onAlertActivated?(alert)
                }
                indicesToRemove.append(index)
            }
        }

        // Remove promoted alerts (reverse order to preserve indices)
        for index in indicesToRemove.reversed() {
            pendingAlerts.remove(at: index)
            pendingReceivedAt.remove(at: index)
        }
    }

    /// Expires active alerts past their TTL and moves them to history.
    private func expireActive(at now: Date) {
        var indicesToRemove: [Int] = []

        for (index, alert) in activeAlerts.enumerated() where alert.isExpired(at: now) {
            alertHistory.append(alert)
            indicesToRemove.append(index)
        }

        // Remove expired alerts
        for index in indicesToRemove.reversed() {
            activeAlerts.remove(at: index)
        }

        // Trim history
        if alertHistory.count > maxHistory {
            alertHistory.removeFirst(alertHistory.count - maxHistory)
        }
    }

    /// Expires pending alerts whose TTL has passed before they could be promoted.
    private func expirePending(at now: Date) {
        var indicesToRemove: [Int] = []

        for (index, alert) in pendingAlerts.enumerated() where alert.isExpired(at: now) {
            indicesToRemove.append(index)
        }

        for index in indicesToRemove.reversed() {
            pendingAlerts.remove(at: index)
            pendingReceivedAt.remove(at: index)
        }
    }
}
