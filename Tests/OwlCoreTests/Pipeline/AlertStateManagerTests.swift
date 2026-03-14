import Testing
import Foundation
@testable import OwlCore

@Suite("AlertStateManager")
@MainActor
struct AlertStateManagerTests {

    // MARK: - Helpers

    private func makeAlert(
        detectorID: String = "test_detector",
        severity: Severity = .warning,
        timestamp: Date = Date(timeIntervalSince1970: 1000),
        ttl: TimeInterval = 300
    ) -> Alert {
        Alert(
            detectorID: detectorID,
            severity: severity,
            title: "Test Alert",
            description: "Something happened",
            suggestion: "Do something",
            timestamp: timestamp,
            ttl: ttl
        )
    }

    // MARK: - Receiving Alerts

    @Test("receives alert and adds to pending")
    func receivesAlertAsPending() {
        let manager = AlertStateManager(debounceInterval: 5)
        let alert = makeAlert()

        manager.receive(alert)

        #expect(manager.pendingAlerts.count == 1)
        #expect(manager.activeAlerts.isEmpty)
    }

    @Test("promotes pending alert to active after debounce")
    func promotesAfterDebounce() {
        let manager = AlertStateManager(debounceInterval: 5)
        let alert = makeAlert(timestamp: Date(timeIntervalSince1970: 1000))

        manager.receive(alert)
        #expect(manager.pendingAlerts.count == 1)

        // Advance past debounce
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1006))

        #expect(manager.pendingAlerts.isEmpty)
        #expect(manager.activeAlerts.count == 1)
    }

    @Test("does not promote before debounce expires")
    func doesNotPromoteEarly() {
        let manager = AlertStateManager(debounceInterval: 5)
        let alert = makeAlert(timestamp: Date(timeIntervalSince1970: 1000))

        manager.receive(alert)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1003))

        #expect(manager.pendingAlerts.count == 1)
        #expect(manager.activeAlerts.isEmpty)
    }

    // MARK: - TTL Expiry

    @Test("expires active alert after TTL")
    func expiresActiveAlertAfterTTL() {
        let manager = AlertStateManager(debounceInterval: 0)
        let alert = makeAlert(
            timestamp: Date(timeIntervalSince1970: 1000),
            ttl: 60
        )

        manager.receive(alert)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1001))
        #expect(manager.activeAlerts.count == 1)

        // Advance past TTL
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1062))
        #expect(manager.activeAlerts.isEmpty)
    }

    @Test("moves expired alert to history")
    func movesExpiredToHistory() {
        let manager = AlertStateManager(debounceInterval: 0)
        let alert = makeAlert(
            timestamp: Date(timeIntervalSince1970: 1000),
            ttl: 60
        )

        manager.receive(alert)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1001))
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1062))

        #expect(manager.alertHistory.count == 1)
        #expect(manager.alertHistory[0].detectorID == "test_detector")
    }

    @Test("limits history to maxHistory entries")
    func limitsHistorySize() {
        let manager = AlertStateManager(debounceInterval: 0, maxHistory: 3)

        for i in 0..<5 {
            let alert = makeAlert(
                detectorID: "det_\(i)",
                timestamp: Date(timeIntervalSince1970: Double(1000 + i * 100)),
                ttl: 10
            )
            manager.receive(alert)
            // Promote immediately
            manager.performMaintenance(
                at: Date(timeIntervalSince1970: Double(1001 + i * 100))
            )
            // Expire it
            manager.performMaintenance(
                at: Date(timeIntervalSince1970: Double(1012 + i * 100))
            )
        }

        #expect(manager.alertHistory.count == 3)
        // Most recent should be last added
        #expect(manager.alertHistory.last?.detectorID == "det_4")
    }

    // MARK: - Severity Aggregation

    @Test("currentSeverity is normal when no alerts")
    func currentSeverityNormalWhenEmpty() {
        let manager = AlertStateManager(debounceInterval: 0)
        #expect(manager.currentSeverity == .normal)
    }

    @Test("currentSeverity is max of active alerts")
    func currentSeverityIsMax() {
        let manager = AlertStateManager(debounceInterval: 0)

        let warning = makeAlert(
            detectorID: "det_1",
            severity: .warning,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        let critical = makeAlert(
            detectorID: "det_2",
            severity: .critical,
            timestamp: Date(timeIntervalSince1970: 1000)
        )

        manager.receive(warning)
        manager.receive(critical)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1001))

        #expect(manager.currentSeverity == .critical)
    }

    @Test("currentSeverity downgrades when critical expires")
    func currentSeverityDowngrades() {
        let manager = AlertStateManager(debounceInterval: 0)

        let warning = makeAlert(
            detectorID: "det_1",
            severity: .warning,
            timestamp: Date(timeIntervalSince1970: 1000),
            ttl: 600
        )
        let critical = makeAlert(
            detectorID: "det_2",
            severity: .critical,
            timestamp: Date(timeIntervalSince1970: 1000),
            ttl: 30
        )

        manager.receive(warning)
        manager.receive(critical)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1001))

        #expect(manager.currentSeverity == .critical)

        // Critical expires, warning remains
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1032))
        #expect(manager.currentSeverity == .warning)
    }

    // MARK: - Same-Detector Update/Upgrade

    @Test("same detector alert upgrades severity")
    func sameDetectorUpgrades() {
        let manager = AlertStateManager(debounceInterval: 0)

        let warning = makeAlert(
            severity: .warning,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        manager.receive(warning)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1001))

        // Same detector, higher severity → upgrade
        let critical = makeAlert(
            severity: .critical,
            timestamp: Date(timeIntervalSince1970: 1010)
        )
        manager.receive(critical)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1011))

        #expect(manager.activeAlerts.count == 1)
        #expect(manager.activeAlerts[0].severity == .critical)
    }

    @Test("same detector alert refreshes TTL on same severity")
    func sameDetectorRefreshesTTL() {
        let manager = AlertStateManager(debounceInterval: 0)

        let alert1 = makeAlert(
            timestamp: Date(timeIntervalSince1970: 1000),
            ttl: 60
        )
        manager.receive(alert1)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1001))

        // Same detector, same severity, later timestamp → refresh TTL
        let alert2 = makeAlert(
            timestamp: Date(timeIntervalSince1970: 1050),
            ttl: 60
        )
        manager.receive(alert2)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1051))

        #expect(manager.activeAlerts.count == 1)
        // Original would expire at 1060, refreshed expires at 1110
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1065))
        #expect(manager.activeAlerts.count == 1, "Refreshed alert should still be active")
    }

    @Test("same detector does not downgrade severity")
    func sameDetectorDoesNotDowngrade() {
        let manager = AlertStateManager(debounceInterval: 0)

        let critical = makeAlert(
            severity: .critical,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        manager.receive(critical)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1001))

        // Same detector, lower severity → keep critical
        let warning = makeAlert(
            severity: .warning,
            timestamp: Date(timeIntervalSince1970: 1010)
        )
        manager.receive(warning)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1011))

        #expect(manager.activeAlerts.count == 1)
        #expect(manager.activeAlerts[0].severity == .critical)
    }

    // MARK: - Pending Expiry

    @Test("pending alert expires if no confirmation within TTL")
    func pendingExpiresWithTTL() {
        let manager = AlertStateManager(debounceInterval: 5)
        let alert = makeAlert(
            timestamp: Date(timeIntervalSince1970: 1000),
            ttl: 3
        )

        manager.receive(alert)
        // TTL (3s) < debounce (5s), so it should expire before promotion
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1004))

        #expect(manager.pendingAlerts.isEmpty)
        #expect(manager.activeAlerts.isEmpty)
    }

    // MARK: - Edge Cases

    @Test("handles multiple detectors simultaneously")
    func handlesMultipleDetectors() {
        let manager = AlertStateManager(debounceInterval: 0)

        let alert1 = makeAlert(
            detectorID: "thermal",
            severity: .warning,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        let alert2 = makeAlert(
            detectorID: "crash_loop",
            severity: .critical,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        let alert3 = makeAlert(
            detectorID: "wifi",
            severity: .info,
            timestamp: Date(timeIntervalSince1970: 1000)
        )

        manager.receive(alert1)
        manager.receive(alert2)
        manager.receive(alert3)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1001))

        #expect(manager.activeAlerts.count == 3)
        #expect(manager.currentSeverity == .critical)
    }

    // MARK: - onAlertActivated Callback

    @Test("calls onAlertActivated when pending alert is promoted")
    func callbackOnPromote() {
        let manager = AlertStateManager(debounceInterval: 5)
        var activatedAlerts: [Alert] = []
        manager.onAlertActivated = { activatedAlerts.append($0) }

        let alert = makeAlert(
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        manager.receive(alert)
        #expect(activatedAlerts.isEmpty)

        // Promote
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1006))
        #expect(activatedAlerts.count == 1)
        #expect(activatedAlerts[0].detectorID == "test_detector")
    }

    @Test("calls onAlertActivated on severity upgrade")
    func callbackOnSeverityUpgrade() {
        let manager = AlertStateManager(debounceInterval: 0)
        var activatedAlerts: [Alert] = []
        manager.onAlertActivated = { activatedAlerts.append($0) }

        let warning = makeAlert(
            severity: .warning,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        manager.receive(warning)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1001))
        #expect(activatedAlerts.count == 1)

        // Upgrade severity
        let critical = makeAlert(
            severity: .critical,
            timestamp: Date(timeIntervalSince1970: 1010)
        )
        manager.receive(critical)
        #expect(activatedAlerts.count == 2)
        #expect(activatedAlerts[1].severity == .critical)
    }

    @Test("does not call onAlertActivated on same-severity TTL refresh")
    func noCallbackOnTTLRefresh() {
        let manager = AlertStateManager(debounceInterval: 0)
        var activatedAlerts: [Alert] = []
        manager.onAlertActivated = { activatedAlerts.append($0) }

        let alert1 = makeAlert(
            severity: .warning,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        manager.receive(alert1)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1001))
        #expect(activatedAlerts.count == 1)

        // Same severity → TTL refresh, should NOT trigger callback
        let alert2 = makeAlert(
            severity: .warning,
            timestamp: Date(timeIntervalSince1970: 1050)
        )
        manager.receive(alert2)
        #expect(activatedAlerts.count == 1, "Same-severity refresh must not trigger callback")
    }

    @Test("does not call onAlertActivated on lower severity")
    func noCallbackOnLowerSeverity() {
        let manager = AlertStateManager(debounceInterval: 0)
        var activatedAlerts: [Alert] = []
        manager.onAlertActivated = { activatedAlerts.append($0) }

        let critical = makeAlert(
            severity: .critical,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        manager.receive(critical)
        manager.performMaintenance(at: Date(timeIntervalSince1970: 1001))
        #expect(activatedAlerts.count == 1)

        // Lower severity → ignored
        let warning = makeAlert(
            severity: .warning,
            timestamp: Date(timeIntervalSince1970: 1010)
        )
        manager.receive(warning)
        #expect(activatedAlerts.count == 1, "Lower severity must not trigger callback")
    }
}
