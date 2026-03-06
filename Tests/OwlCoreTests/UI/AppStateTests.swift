import Foundation
import Testing
@testable import OwlCore

@Suite("AppState")
struct AppStateTests {

    // MARK: - Initial State

    @Test @MainActor func initialSeverityIsNormal() {
        let state = AppState()
        #expect(state.currentSeverity == .normal)
        #expect(state.previousSeverity == nil)
    }

    @Test @MainActor func initialActiveAlertsIsEmpty() {
        let state = AppState()
        #expect(state.activeAlerts.isEmpty)
    }

    @Test @MainActor func initialMetricsAreZero() {
        let state = AppState()
        #expect(state.metrics.cpuUsage == 0)
        #expect(state.metrics.memoryPressure == 0)
    }

    // MARK: - Alert Updates

    @Test @MainActor func updateAlertsSetsActiveAlerts() {
        let state = AppState()
        let alert = makeAlert(detector: "test", severity: .warning)
        state.updateAlerts(active: [alert], history: [], severity: .warning)
        #expect(state.activeAlerts.count == 1)
        #expect(state.currentSeverity == .warning)
    }

    @Test @MainActor func updateAlertsSortsBySeverityDescending() {
        let state = AppState()
        let warning = makeAlert(detector: "a", severity: .warning)
        let critical = makeAlert(detector: "b", severity: .critical)
        let info = makeAlert(detector: "c", severity: .info)

        state.updateAlerts(
            active: [warning, info, critical],
            history: [],
            severity: .critical
        )

        #expect(state.activeAlerts[0].severity == .critical)
        #expect(state.activeAlerts[1].severity == .warning)
        #expect(state.activeAlerts[2].severity == .info)
    }

    @Test @MainActor func updateAlertsTracksPreviousSeverity() {
        let state = AppState()
        let alert = makeAlert(detector: "test", severity: .warning)

        // First update: normal → warning
        state.updateAlerts(active: [alert], history: [], severity: .warning)
        #expect(state.previousSeverity == .normal)

        // Second update: warning → critical
        let critical = makeAlert(detector: "test2", severity: .critical)
        state.updateAlerts(
            active: [critical], history: [], severity: .critical
        )
        #expect(state.previousSeverity == .warning)
    }

    @Test @MainActor func updateAlertsSetsHistory() {
        let state = AppState()
        let expired = makeAlert(detector: "old", severity: .info)
        state.updateAlerts(active: [], history: [expired], severity: .normal)
        #expect(state.alertHistory.count == 1)
    }

    // MARK: - Metrics Updates

    @Test @MainActor func updateMetricsSetsValues() {
        let state = AppState()
        let metrics = SystemMetrics(
            cpuUsage: 45.5,
            memoryTotal: 16_000_000_000,
            memoryUsed: 10_752_000_000
        )
        state.updateMetrics(metrics)
        #expect(state.metrics.cpuUsage == 45.5)
        #expect(state.metrics.memoryTotal == 16_000_000_000)
    }

    // MARK: - Helpers

    private func makeAlert(
        detector: String,
        severity: Severity
    ) -> Alert {
        Alert(
            detectorID: detector,
            severity: severity,
            title: "Test",
            description: "Test alert",
            suggestion: "Do something",
            timestamp: Date()
        )
    }
}
