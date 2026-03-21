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

    @Test("accepts Deep Idle DarkWake entries")
    func acceptsDeepIdleDarkWake() {
        let detector = DarkWakePattern.makeDetector()
        let entry = TestFixtures.DarkWake.entry(TestFixtures.DarkWake.deepIdle)
        #expect(detector.accepts(entry))
    }

    @Test("accepts but does not count PMRD status noise")
    func rejectsPMRDNoise() {
        let detector = DarkWakePattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)
        let entry = TestFixtures.DarkWake.entry(
            TestFixtures.DarkWake.pmrdNoise,
            timestamp: t0
        )
        // accepts() passes (contains "DarkWake"), but process() must not count it
        #expect(detector.accepts(entry))
        #expect(detector.process(entry) == nil)
        #expect(detector.groupCount == 0)
    }

    @Test("accepts but does not count GPU crossbar noise")
    func rejectsGPUNoise() {
        let detector = DarkWakePattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)
        let entry = TestFixtures.DarkWake.entry(
            TestFixtures.DarkWake.gpuNoise,
            timestamp: t0
        )
        #expect(detector.accepts(entry))
        #expect(detector.process(entry) == nil)
        #expect(detector.groupCount == 0)
    }

    @Test("noise messages do not inflate real DarkWake count")
    func noiseDoesNotInflateCount() {
        let detector = DarkWakePattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        // Feed 5 real DarkWake events + 50 noise messages
        for i in 0..<5 {
            let real = TestFixtures.DarkWake.entry(
                TestFixtures.DarkWake.wake,
                timestamp: t0.addingTimeInterval(Double(i) * 60)
            )
            _ = detector.process(real)

            // 10 noise messages per real event
            for idx in 0..<10 {
                let noise = TestFixtures.DarkWake.entry(
                    TestFixtures.DarkWake.pmrdNoise,
                    timestamp: t0.addingTimeInterval(Double(i) * 60 + Double(idx) + 1)
                )
                _ = detector.process(noise)
            }
        }

        // Should NOT trigger warning (only 5 real events, threshold is 10)
        // If noise were counted, it would be 55 events → critical
        #expect(detector.groupCount == 1)
    }
}
