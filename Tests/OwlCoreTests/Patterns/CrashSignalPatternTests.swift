import Testing
import Foundation
@testable import OwlCore

@Suite("P07 CrashSignalPattern")
struct CrashSignalPatternTests {

    @Test("has correct ID")
    func hasCorrectID() {
        let detector = CrashSignalPattern.makeDetector()
        #expect(detector.id == "process_crash_signal")
    }

    @Test("accepts exited-due-to log entries")
    func acceptsCrashEntries() {
        let detector = CrashSignalPattern.makeDetector()
        let entry = TestFixtures.CrashSignal.entry(TestFixtures.CrashSignal.sigkill)
        #expect(detector.accepts(entry))
    }

    @Test("rejects unrelated launchd entries")
    func rejectsUnrelatedEntries() {
        let detector = CrashSignalPattern.makeDetector()
        let entry = TestFixtures.makeEntry(
            message: "launchd: service started",
            process: "launchd"
        )
        #expect(!detector.accepts(entry))
    }

    @Test("triggers warning after 3 crashes of same service")
    func triggersWarningAt3() {
        let detector = CrashSignalPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        for i in 0..<2 {
            let entry = TestFixtures.CrashSignal.entry(
                TestFixtures.CrashSignal.sigkill,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            let alert = detector.process(entry)
            #expect(alert == nil)
        }

        let entry3 = TestFixtures.CrashSignal.entry(
            TestFixtures.CrashSignal.sigkill,
            timestamp: t0.addingTimeInterval(2)
        )
        let alert = detector.process(entry3)
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
    }

    @Test("groups by service name")
    func groupsByServiceName() {
        let detector = CrashSignalPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        // 3 SIGKILL for service A
        for i in 0..<3 {
            let entry = TestFixtures.CrashSignal.entry(
                TestFixtures.CrashSignal.sigkill,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            _ = detector.process(entry)
        }

        // Different service (sigsegv) should not trigger
        let otherEntry = TestFixtures.CrashSignal.entry(
            TestFixtures.CrashSignal.sigsegv,
            timestamp: t0.addingTimeInterval(3)
        )
        let alert = detector.process(otherEntry)
        #expect(alert == nil, "Different service at count 1 should not trigger")
    }

    @Test("accepts different signal types")
    func acceptsDifferentSignals() {
        let detector = CrashSignalPattern.makeDetector()

        let sigkill = TestFixtures.CrashSignal.entry(TestFixtures.CrashSignal.sigkill)
        let sigsegv = TestFixtures.CrashSignal.entry(TestFixtures.CrashSignal.sigsegv)
        let sigabrt = TestFixtures.CrashSignal.entry(TestFixtures.CrashSignal.sigabrt)

        #expect(detector.accepts(sigkill))
        #expect(detector.accepts(sigsegv))
        #expect(detector.accepts(sigabrt))
    }
}
