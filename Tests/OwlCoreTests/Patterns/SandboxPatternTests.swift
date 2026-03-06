import Testing
import Foundation
@testable import OwlCore

@Suite("P05 SandboxPattern")
struct SandboxPatternTests {

    @Test("has correct ID")
    func hasCorrectID() {
        let detector = SandboxPattern.makeDetector()
        #expect(detector.id == "sandbox_violation_storm")
    }

    @Test("accepts sandbox deny log entries")
    func acceptsSandboxDenyEntries() {
        let detector = SandboxPattern.makeDetector()
        let entry = TestFixtures.Sandbox.entry(TestFixtures.Sandbox.deny)
        #expect(detector.accepts(entry))
    }

    @Test("rejects non-deny entries")
    func rejectsNonDenyEntries() {
        let detector = SandboxPattern.makeDetector()
        let entry = TestFixtures.makeEntry(message: "Sandbox: some allowed operation")
        #expect(!detector.accepts(entry))
    }

    @Test("triggers warning after 10 deny events from same process")
    func triggersWarningAt10() {
        let detector = SandboxPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        for i in 0..<9 {
            let entry = TestFixtures.Sandbox.entry(
                TestFixtures.Sandbox.deny,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            let alert = detector.process(entry)
            #expect(alert == nil)
        }

        let entry10 = TestFixtures.Sandbox.entry(
            TestFixtures.Sandbox.deny,
            timestamp: t0.addingTimeInterval(9)
        )
        let alert = detector.process(entry10)
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
    }

    @Test("groups by process name")
    func groupsByProcessName() {
        let detector = SandboxPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        // 10 events from Chrome
        for i in 0..<10 {
            let entry = TestFixtures.Sandbox.entry(
                TestFixtures.Sandbox.deny,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            _ = detector.process(entry)
        }

        // Different process should not trigger
        let otherDeny = #"Sandbox: Firefox(12345) deny(1) file-read-data /tmp"#
        let otherEntry = TestFixtures.Sandbox.entry(
            otherDeny,
            timestamp: t0.addingTimeInterval(10)
        )
        let alert = detector.process(otherEntry)
        #expect(alert == nil, "Different process at count 1 should not trigger")
    }

    @Test("alert description contains process name")
    func alertContainsProcessName() {
        let detector = SandboxPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        var lastAlert: Alert?
        for i in 0..<10 {
            let entry = TestFixtures.Sandbox.entry(
                TestFixtures.Sandbox.deny,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            lastAlert = detector.process(entry) ?? lastAlert
        }

        #expect(lastAlert?.description.contains("Google Chrome") == true)
    }
}
