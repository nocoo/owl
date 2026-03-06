import Testing
import Foundation
@testable import OwlCore

@Suite("P06 SleepAssertionPattern")
struct SleepAssertionPatternTests {

    @Test("has correct ID")
    func hasCorrectID() {
        let detector = SleepAssertionPattern.makeDetector()
        #expect(detector.id == "sleep_assertion_leak")
    }

    @Test("accepts Created sleep assertion entries")
    func acceptsCreatedEntries() {
        let detector = SleepAssertionPattern.makeDetector()
        let entry = TestFixtures.SleepAssertion.entry(
            TestFixtures.SleepAssertion.created
        )
        #expect(detector.accepts(entry))
    }

    @Test("accepts Released sleep assertion entries")
    func acceptsReleasedEntries() {
        let detector = SleepAssertionPattern.makeDetector()
        let entry = TestFixtures.SleepAssertion.entry(
            TestFixtures.SleepAssertion.released
        )
        #expect(detector.accepts(entry))
    }

    @Test("rejects unrelated powerd entries")
    func rejectsUnrelatedEntries() {
        let detector = SleepAssertionPattern.makeDetector()
        let entry = TestFixtures.makeEntry(
            message: "powerd: some other message",
            process: "powerd"
        )
        #expect(!detector.accepts(entry))
    }

    @Test("tracks created assertion and pairs with release")
    func tracksPairing() {
        let detector = SleepAssertionPattern.makeDetector()

        let createdEntry = TestFixtures.SleepAssertion.entry(
            TestFixtures.SleepAssertion.created
        )
        _ = detector.process(createdEntry)
        #expect(detector.pendingCount == 1)

        let releasedEntry = TestFixtures.SleepAssertion.entry(
            TestFixtures.SleepAssertion.released
        )
        _ = detector.process(releasedEntry)
        #expect(detector.pendingCount == 0)
    }

    @Test("emits warning after 30 minutes unreleased")
    func warningAfter30Minutes() {
        let detector = SleepAssertionPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        let createdEntry = TestFixtures.SleepAssertion.entry(
            TestFixtures.SleepAssertion.created,
            timestamp: t0
        )
        _ = detector.process(createdEntry)

        // Advance 31 minutes
        detector.advanceTimeForTesting(to: t0.addingTimeInterval(1860))
        let alerts = detector.tick()

        #expect(alerts.count == 1)
        #expect(alerts.first?.severity == .warning)
    }

    @Test("escalates to critical after 2 hours unreleased")
    func criticalAfter2Hours() {
        let detector = SleepAssertionPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        let createdEntry = TestFixtures.SleepAssertion.entry(
            TestFixtures.SleepAssertion.created,
            timestamp: t0
        )
        _ = detector.process(createdEntry)

        // Trigger warning first
        detector.advanceTimeForTesting(to: t0.addingTimeInterval(1860))
        _ = detector.tick()

        // Advance to 2+ hours
        detector.advanceTimeForTesting(to: t0.addingTimeInterval(7300))
        let alerts = detector.tick()

        #expect(alerts.count == 1)
        #expect(alerts.first?.severity == .critical)
    }

    @Test("alert description contains source name")
    func alertContainsSource() {
        let detector = SleepAssertionPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        let createdEntry = TestFixtures.SleepAssertion.entry(
            TestFixtures.SleepAssertion.created,
            timestamp: t0
        )
        _ = detector.process(createdEntry)

        detector.advanceTimeForTesting(to: t0.addingTimeInterval(1860))
        let alerts = detector.tick()

        // Source is capture group 3: the quoted identifier
        #expect(alerts.first?.description.contains("AppleHDAEngineOutput") == true)
    }
}
