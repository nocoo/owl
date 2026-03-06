import Foundation
import Testing
@testable import OwlCore

@Suite("StateDetector")
struct StateDetectorTests {

    // MARK: - Helpers

    private func makeConfig(
        warningAge: TimeInterval = 300,
        criticalAge: TimeInterval = 600,
        maxTracked: Int = 100
    ) -> StateConfig {
        StateConfig(
            id: "P06",
            createdRegex: #"IOPMAssertionCreated \[id=(\d+)\] \[type=(.+?)\] \[source=(.+?)\]"#,
            releasedRegex: #"IOPMAssertionReleased \[id=(\d+)\]"#,
            warningAge: warningAge,
            criticalAge: criticalAge,
            maxTracked: maxTracked,
            title: "Sleep Assertion Leak",
            descriptionTemplate: "Assertion {id} ({type}) from {source} held for {age}s",
            suggestion: "An app may be preventing sleep unnecessarily",
            acceptsFilter: "IOPMAssertion"
        )
    }

    private func makeEntry(
        message: String,
        timestamp: Date = Date()
    ) -> LogEntry {
        LogEntry(
            timestamp: timestamp,
            process: "powerd",
            processID: 80,
            subsystem: "com.apple.powermanagement",
            category: "assertions",
            messageType: "Default",
            eventMessage: message
        )
    }

    // MARK: - accepts()

    @Test func acceptsMatchingMessage() {
        let detector = StateDetector(config: makeConfig())
        let msg = "IOPMAssertionCreated [id=123] [type=PreventUserIdleSystemSleep] [source=com.spotify]"
        let entry = makeEntry(message: msg)
        #expect(detector.accepts(entry))
    }

    @Test func rejectsNonMatchingMessage() {
        let detector = StateDetector(config: makeConfig())
        let entry = makeEntry(message: "some random power log")
        #expect(!detector.accepts(entry))
    }

    // MARK: - Created event tracking

    @Test func createdEventIsTracked() {
        let detector = StateDetector(config: makeConfig())
        let entry = makeEntry(
            message: "IOPMAssertionCreated [id=42] [type=PreventUserIdleSystemSleep] [source=com.spotify.client]"
        )

        let alert = detector.process(entry)
        #expect(alert == nil) // Created events never produce alerts
        #expect(detector.pendingCount == 1)
    }

    @Test func multipleCreatedEventsTracked() {
        let detector = StateDetector(config: makeConfig())
        let t0 = Date()

        _ = detector.process(makeEntry(
            message: "IOPMAssertionCreated [id=1] [type=Sleep] [source=com.app1]",
            timestamp: t0
        ))
        _ = detector.process(makeEntry(
            message: "IOPMAssertionCreated [id=2] [type=Sleep] [source=com.app2]",
            timestamp: t0.addingTimeInterval(1)
        ))

        #expect(detector.pendingCount == 2)
    }

    // MARK: - Released event pairing

    @Test func releasedEventRemovesTrackedAssertion() {
        let detector = StateDetector(config: makeConfig())
        let t0 = Date()

        _ = detector.process(makeEntry(
            message: "IOPMAssertionCreated [id=42] [type=Sleep] [source=com.app]",
            timestamp: t0
        ))
        #expect(detector.pendingCount == 1)

        let alert = detector.process(makeEntry(
            message: "IOPMAssertionReleased [id=42]",
            timestamp: t0.addingTimeInterval(10)
        ))

        #expect(alert == nil) // Normal pairing — no alert
        #expect(detector.pendingCount == 0)
    }

    @Test func releasedForUnknownIDIsNoOp() {
        let detector = StateDetector(config: makeConfig())
        let alert = detector.process(makeEntry(message: "IOPMAssertionReleased [id=999]"))

        #expect(alert == nil)
        #expect(detector.pendingCount == 0)
    }

    // MARK: - tick() leak detection — warning

    @Test func tickEmitsWarningForAgedAssertion() {
        let detector = StateDetector(config: makeConfig(warningAge: 10, criticalAge: 60))
        let t0 = Date()

        _ = detector.process(makeEntry(
            message: "IOPMAssertionCreated [id=1] [type=Sleep] [source=com.app]",
            timestamp: t0
        ))

        // Advance past warning age
        detector.advanceTimeForTesting(to: t0.addingTimeInterval(15))
        let alerts = detector.tick()

        #expect(alerts.count == 1)
        #expect(alerts[0].severity == .warning)
        #expect(alerts[0].detectorID == "P06")
    }

    // MARK: - tick() leak detection — critical

    @Test func tickEmitsCriticalForVeryAgedAssertion() {
        let detector = StateDetector(config: makeConfig(warningAge: 10, criticalAge: 30))
        let t0 = Date()

        _ = detector.process(makeEntry(
            message: "IOPMAssertionCreated [id=1] [type=Sleep] [source=com.app]",
            timestamp: t0
        ))

        // Advance past critical age
        detector.advanceTimeForTesting(to: t0.addingTimeInterval(35))
        let alerts = detector.tick()

        #expect(alerts.count == 1)
        #expect(alerts[0].severity == .critical)
    }

    // MARK: - tick() does not re-alert same severity

    @Test func tickDoesNotReAlertSameSeverity() {
        let detector = StateDetector(config: makeConfig(warningAge: 10, criticalAge: 60))
        let t0 = Date()

        _ = detector.process(makeEntry(
            message: "IOPMAssertionCreated [id=1] [type=Sleep] [source=com.app]",
            timestamp: t0
        ))

        // First tick: warning
        detector.advanceTimeForTesting(to: t0.addingTimeInterval(15))
        let first = detector.tick()
        #expect(first.count == 1)

        // Second tick: should not re-alert at warning
        detector.advanceTimeForTesting(to: t0.addingTimeInterval(20))
        let second = detector.tick()
        #expect(second.isEmpty)
    }

    // MARK: - tick() upgrades from warning to critical

    @Test func tickUpgradesWarningToCritical() {
        let detector = StateDetector(config: makeConfig(warningAge: 10, criticalAge: 30))
        let t0 = Date()

        _ = detector.process(makeEntry(
            message: "IOPMAssertionCreated [id=1] [type=Sleep] [source=com.app]",
            timestamp: t0
        ))

        // First tick: warning
        detector.advanceTimeForTesting(to: t0.addingTimeInterval(15))
        let warning = detector.tick()
        #expect(warning.count == 1)
        #expect(warning[0].severity == .warning)

        // Second tick after critical age: upgrade to critical
        detector.advanceTimeForTesting(to: t0.addingTimeInterval(35))
        let critical = detector.tick()
        #expect(critical.count == 1)
        #expect(critical[0].severity == .critical)
    }

    // MARK: - tick() cleans up very old entries

    @Test func tickCleansUpSuperOldEntries() {
        let detector = StateDetector(config: makeConfig(warningAge: 10, criticalAge: 30))
        let t0 = Date()

        _ = detector.process(makeEntry(
            message: "IOPMAssertionCreated [id=1] [type=Sleep] [source=com.app]",
            timestamp: t0
        ))

        // Advance past 3x critical age — should auto-cleanup
        detector.advanceTimeForTesting(to: t0.addingTimeInterval(100))
        _ = detector.tick()

        #expect(detector.pendingCount == 0)
    }

    // MARK: - FIFO eviction when maxTracked exceeded

    @Test func evictsOldestWhenMaxTrackedExceeded() {
        let detector = StateDetector(config: makeConfig(maxTracked: 3))
        let t0 = Date()

        for i in 1...4 {
            _ = detector.process(makeEntry(
                message: "IOPMAssertionCreated [id=\(i)] [type=Sleep] [source=com.app\(i)]",
                timestamp: t0.addingTimeInterval(Double(i))
            ))
        }

        // Should have evicted the oldest, keeping 3
        #expect(detector.pendingCount == 3)
    }

    // MARK: - process() never produces alerts

    @Test func processNeverProducesAlerts() {
        let detector = StateDetector(config: makeConfig())
        let t0 = Date()

        let alert1 = detector.process(makeEntry(
            message: "IOPMAssertionCreated [id=1] [type=Sleep] [source=com.app]",
            timestamp: t0
        ))
        let alert2 = detector.process(makeEntry(
            message: "IOPMAssertionReleased [id=1]",
            timestamp: t0.addingTimeInterval(5)
        ))

        #expect(alert1 == nil)
        #expect(alert2 == nil)
    }

    // MARK: - Multiple assertions in tick

    @Test func tickEmitsAlertsForMultipleLeakedAssertions() {
        let detector = StateDetector(config: makeConfig(warningAge: 10, criticalAge: 60))
        let t0 = Date()

        _ = detector.process(makeEntry(
            message: "IOPMAssertionCreated [id=1] [type=A] [source=app1]",
            timestamp: t0
        ))
        _ = detector.process(makeEntry(
            message: "IOPMAssertionCreated [id=2] [type=B] [source=app2]",
            timestamp: t0.addingTimeInterval(1)
        ))

        detector.advanceTimeForTesting(to: t0.addingTimeInterval(15))
        let alerts = detector.tick()

        #expect(alerts.count == 2)
    }

    // MARK: - isEnabled

    @Test func isEnabledDefaultsToTrue() {
        let detector = StateDetector(config: makeConfig())
        #expect(detector.isEnabled)
    }

    // MARK: - Description includes assertion info

    @Test func alertDescriptionIncludesAssertionDetails() {
        let detector = StateDetector(config: makeConfig(warningAge: 5, criticalAge: 60))
        let t0 = Date()

        _ = detector.process(makeEntry(
            message: "IOPMAssertionCreated [id=42] [type=PreventSleep] [source=com.spotify]",
            timestamp: t0
        ))

        detector.advanceTimeForTesting(to: t0.addingTimeInterval(10))
        let alerts = detector.tick()

        #expect(alerts.count == 1)
        #expect(alerts[0].description.contains("42") == true)
        #expect(alerts[0].description.contains("PreventSleep") == true)
        #expect(alerts[0].description.contains("com.spotify") == true)
    }
}
