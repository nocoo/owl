import Testing
import Foundation
@testable import OwlCore

@Suite("P14 DarkWakePattern")
struct DarkWakePatternTests {

    @Test("has correct ID")
    func hasCorrectID() {
        let detector = DarkWakePattern.makeDetector()
        #expect(detector.id == "darkwake_abnormal")
    }

    @Test("accepts DarkWake log entries")
    func acceptsDarkWakeEntries() {
        let detector = DarkWakePattern.makeDetector()
        let entry = TestFixtures.DarkWake.entry(TestFixtures.DarkWake.wake)
        #expect(detector.accepts(entry))
    }

    @Test("rejects unrelated kernel entries")
    func rejectsUnrelatedEntries() {
        let detector = DarkWakePattern.makeDetector()
        let entry = TestFixtures.makeEntry(message: "kernel: normal wake")
        #expect(!detector.accepts(entry))
    }

    @Test("triggers warning after 10 DarkWake events globally")
    func triggersWarningAt10() {
        let detector = DarkWakePattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        for i in 0..<9 {
            let entry = TestFixtures.DarkWake.entry(
                TestFixtures.DarkWake.wake,
                timestamp: t0.addingTimeInterval(Double(i) * 60)
            )
            #expect(detector.process(entry) == nil)
        }

        let entry10 = TestFixtures.DarkWake.entry(
            TestFixtures.DarkWake.wake,
            timestamp: t0.addingTimeInterval(540)
        )
        let alert = detector.process(entry10)
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
    }

    @Test("escalates to critical after 30 events")
    func escalatesToCriticalAt30() {
        let detector = DarkWakePattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        var alerts: [Alert] = []
        for i in 0..<30 {
            let entry = TestFixtures.DarkWake.entry(
                TestFixtures.DarkWake.wake,
                timestamp: t0.addingTimeInterval(Double(i) * 60)
            )
            if let alert = detector.process(entry) {
                alerts.append(alert)
            }
        }

        // Event 10 (t+540): warning (count=10)
        // Event 20 (t+1140): warning again (cooldown 600s expired, count=20 still < 30)
        // Event 30 (t+1740): critical (cooldown 600s expired, count=30)
        #expect(alerts.count == 3)
        #expect(alerts[0].severity == .warning)
        #expect(alerts[1].severity == .warning)
        #expect(alerts[2].severity == .critical)
    }

    @Test("uses global grouping")
    func usesGlobalGrouping() {
        let detector = DarkWakePattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        let entry = TestFixtures.DarkWake.entry(
            TestFixtures.DarkWake.wake,
            timestamp: t0
        )
        _ = detector.process(entry)

        #expect(detector.groupCount == 1)
    }
}
