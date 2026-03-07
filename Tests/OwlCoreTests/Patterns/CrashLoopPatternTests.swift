import Testing
import Foundation
@testable import OwlCore

@Suite("P02 CrashLoopPattern")
struct CrashLoopPatternTests {

    @Test("has correct ID")
    func hasCorrectID() {
        let detector = CrashLoopPattern.makeDetector()
        #expect(detector.id == "process_crash_loop")
    }

    @Test("accepts QUIT log entries")
    func acceptsQuitEntries() {
        let detector = CrashLoopPattern.makeDetector()
        let entry = TestFixtures.CrashLoop.entry(TestFixtures.CrashLoop.quit)
        #expect(detector.accepts(entry))
    }

    @Test("rejects CHECKIN entries (no QUIT keyword)")
    func rejectsCheckinEntries() {
        let detector = CrashLoopPattern.makeDetector()
        let entry = TestFixtures.CrashLoop.entry(TestFixtures.CrashLoop.checkin)
        #expect(!detector.accepts(entry))
    }

    @Test("triggers warning after 5 QUIT events in 60s window")
    func triggersWarningAt5() {
        let detector = CrashLoopPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        for i in 0..<4 {
            let entry = TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.quit,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            let alert = detector.process(entry)
            #expect(alert == nil, "Should not alert at count \(i + 1)")
        }

        // 5th event triggers warning
        let entry5 = TestFixtures.CrashLoop.entry(
            TestFixtures.CrashLoop.quit,
            timestamp: t0.addingTimeInterval(4)
        )
        let alert = detector.process(entry5)
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
    }

    @Test("escalates from warning to critical within same window")
    func escalatesToCritical() {
        let detector = CrashLoopPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        // Rapidly send 25 events
        var alerts: [Alert] = []
        for i in 0..<25 {
            let entry = TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.quit,
                timestamp: t0.addingTimeInterval(Double(i) * 0.1)
            )
            if let alert = detector.process(entry) {
                alerts.append(alert)
            }
        }

        // Warning at count 5, escalation to critical at count 20
        #expect(alerts.count == 2)
        #expect(alerts[0].severity == .warning)
        #expect(alerts[1].severity == .critical)
    }

    @Test("respects cooldown — no re-alert within 120s")
    func respectsCooldown() {
        let detector = CrashLoopPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        // Trigger warning (5 events)
        for i in 0..<5 {
            let entry = TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.quit,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            _ = detector.process(entry)
        }

        // More events within cooldown should not alert
        for i in 5..<10 {
            let entry = TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.quit,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            let alert = detector.process(entry)
            // After warning at 5, critical at 20 hasn't been reached,
            // and warning is already emitted — so should be nil
            // (unless critical threshold is met)
            if alert != nil {
                #expect(alert?.severity == .critical)
            }
        }
    }

    @Test("alert contains app name in description")
    func alertContainsAppName() {
        let detector = CrashLoopPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        var lastAlert: Alert?
        for i in 0..<5 {
            let entry = TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.quit,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            lastAlert = detector.process(entry) ?? lastAlert
        }

        #expect(lastAlert?.description.contains("com.example.app") == true)
    }

    @Test("accepts but does not count noise QUIT messages without name field")
    func acceptsButDoesNotCountNoiseMessages() {
        let detector = CrashLoopPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)
        let entry = TestFixtures.CrashLoop.entry(
            TestFixtures.CrashLoop.noiseQuit,
            timestamp: t0
        )
        // Contains "QUIT:" so accepts() passes
        #expect(detector.accepts(entry))
        // But regex requires `name = "..."` — process() must not count it
        #expect(detector.process(entry) == nil)
        #expect(detector.groupCount == 0)
    }

    @Test("noise QUIT messages do not inflate real crash count")
    func noiseDoesNotInflateRealCount() {
        let detector = CrashLoopPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        // Feed 3 real QUIT events (below warning threshold of 5)
        for i in 0..<3 {
            _ = detector.process(TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.quit,
                timestamp: t0.addingTimeInterval(Double(i))
            ))
        }

        // Flood with 20 noise messages
        for i in 0..<20 {
            _ = detector.process(TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.noiseQuit,
                timestamp: t0.addingTimeInterval(Double(i + 3))
            ))
        }

        // Feed 1 more real event (total real = 4, still below threshold of 5)
        let alert = detector.process(TestFixtures.CrashLoop.entry(
            TestFixtures.CrashLoop.quit,
            timestamp: t0.addingTimeInterval(23)
        ))
        #expect(alert == nil, "Noise should not push real count past warning threshold")
    }
}
