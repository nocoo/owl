import Testing
import Foundation
@testable import OwlCore

@Suite("P10 JetsamPattern")
struct JetsamPatternTests {

    @Test("primary detector has correct ID")
    func primaryHasCorrectID() {
        let detector = JetsamPattern.makeDetector()
        #expect(detector.id == "jetsam_kill")
    }

    @Test("escalation detector has correct ID")
    func escalationHasCorrectID() {
        let detector = JetsamPattern.makeEscalationDetector()
        #expect(detector.id == "jetsam_kill_escalation")
    }

    @Test("accepts memorystatus_kill log entries")
    func acceptsJetsamEntries() {
        let detector = JetsamPattern.makeDetector()
        let entry = TestFixtures.Jetsam.entry(TestFixtures.Jetsam.kill)
        #expect(detector.accepts(entry))
    }

    @Test("rejects unrelated kernel entries")
    func rejectsUnrelatedEntries() {
        let detector = JetsamPattern.makeDetector()
        let entry = TestFixtures.makeEntry(message: "kernel: some message")
        #expect(!detector.accepts(entry))
    }

    @Test("single kill triggers immediate warning (zero debounce)")
    func singleKillTriggersWarning() {
        let detector = JetsamPattern.makeDetector()
        let entry = TestFixtures.Jetsam.entry(TestFixtures.Jetsam.kill)
        let alert = detector.process(entry)
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
    }

    @Test("escalation detector triggers critical at 3 kills in 5 min")
    func escalationTriggersCritical() {
        let detector = JetsamPattern.makeEscalationDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        for i in 0..<2 {
            let entry = TestFixtures.Jetsam.entry(
                TestFixtures.Jetsam.kill,
                timestamp: t0.addingTimeInterval(Double(i) * 10)
            )
            #expect(detector.process(entry) == nil)
        }

        let entry3 = TestFixtures.Jetsam.entry(
            TestFixtures.Jetsam.kill,
            timestamp: t0.addingTimeInterval(20)
        )
        let alert = detector.process(entry3)
        #expect(alert != nil)
        #expect(alert?.severity == .critical)
    }

    @Test("both detectors accept the same log entry")
    func bothDetectorsAcceptSameEntry() {
        let primary = JetsamPattern.makeDetector()
        let escalation = JetsamPattern.makeEscalationDetector()
        let entry = TestFixtures.Jetsam.entry(TestFixtures.Jetsam.kill)

        #expect(primary.accepts(entry))
        #expect(escalation.accepts(entry))
    }
}
