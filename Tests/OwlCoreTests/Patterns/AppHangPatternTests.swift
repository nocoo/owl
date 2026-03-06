import Testing
import Foundation
@testable import OwlCore

@Suite("P11 AppHangPattern")
struct AppHangPatternTests {

    @Test("has correct ID")
    func hasCorrectID() {
        let detector = AppHangPattern.makeDetector()
        #expect(detector.id == "app_hang")
    }

    @Test("accepts ping failure log entries")
    func acceptsPingFailureEntries() {
        let detector = AppHangPattern.makeDetector()
        let entry = TestFixtures.AppHang.entry(TestFixtures.AppHang.hang)
        #expect(detector.accepts(entry))
    }

    @Test("rejects unrelated WindowServer entries")
    func rejectsUnrelatedEntries() {
        let detector = AppHangPattern.makeDetector()
        let entry = TestFixtures.makeEntry(
            message: "WindowServer: display reconfigured",
            process: "WindowServer"
        )
        #expect(!detector.accepts(entry))
    }

    @Test("triggers warning after 2 ping failures for same PID")
    func triggersWarningAt2() {
        let detector = AppHangPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        let entry1 = TestFixtures.AppHang.entry(
            TestFixtures.AppHang.hang,
            timestamp: t0
        )
        #expect(detector.process(entry1) == nil)

        let entry2 = TestFixtures.AppHang.entry(
            TestFixtures.AppHang.hang,
            timestamp: t0.addingTimeInterval(1)
        )
        let alert = detector.process(entry2)
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
    }

    @Test("groups by PID")
    func groupsByPID() {
        let detector = AppHangPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        // 2 failures for PID 85412
        for i in 0..<2 {
            let entry = TestFixtures.AppHang.entry(
                TestFixtures.AppHang.hang,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            _ = detector.process(entry)
        }

        // Different PID should not trigger
        let otherHang = "[pid=99999] failed to act on a ping. Removing"
        let entry = TestFixtures.AppHang.entry(
            otherHang,
            timestamp: t0.addingTimeInterval(2)
        )
        let alert = detector.process(entry)
        #expect(alert == nil, "Different PID at count 1 should not trigger")
    }
}
