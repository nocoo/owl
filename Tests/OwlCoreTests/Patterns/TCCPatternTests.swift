import Testing
import Foundation
@testable import OwlCore

@Suite("P09 TCCPattern")
struct TCCPatternTests {

    @Test("has correct ID")
    func hasCorrectID() {
        let detector = TCCPattern.makeDetector()
        #expect(detector.id == "tcc_permission_storm")
    }

    @Test("accepts AUTHREQ_RESULT log entries")
    func acceptsDeniedEntries() {
        let detector = TCCPattern.makeDetector()
        let entry = TestFixtures.TCC.entry(TestFixtures.TCC.denied)
        #expect(detector.accepts(entry))
    }

    @Test("rejects unrelated tccd entries")
    func rejectsUnrelatedEntries() {
        let detector = TCCPattern.makeDetector()
        let entry = TestFixtures.makeEntry(
            message: "tccd: database migration",
            process: "tccd"
        )
        #expect(!detector.accepts(entry))
    }

    @Test("triggers warning after 10 DENIED events from same app")
    func triggersWarningAt10() {
        let detector = TCCPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        for i in 0..<9 {
            let entry = TestFixtures.TCC.entry(
                TestFixtures.TCC.denied,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            #expect(detector.process(entry) == nil)
        }

        let entry10 = TestFixtures.TCC.entry(
            TestFixtures.TCC.denied,
            timestamp: t0.addingTimeInterval(9)
        )
        let alert = detector.process(entry10)
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
    }

    @Test("alert contains bundle ID")
    func alertContainsBundleID() {
        let detector = TCCPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        var lastAlert: Alert?
        for i in 0..<10 {
            let entry = TestFixtures.TCC.entry(
                TestFixtures.TCC.denied,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            lastAlert = detector.process(entry) ?? lastAlert
        }

        #expect(lastAlert?.description.contains("com.example.app") == true)
    }
}
