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

    @Test("accepts System Policy deny log entries")
    func acceptsSystemPolicyDenyEntries() {
        let detector = SandboxPattern.makeDetector()
        let entry = TestFixtures.Sandbox.entry(TestFixtures.Sandbox.systemPolicyDeny)
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

    @Test("extracts process name from System Policy deny entries")
    func extractsProcessNameFromSystemPolicy() {
        let detector = SandboxPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 2000)

        var lastAlert: Alert?
        for i in 0..<10 {
            let entry = TestFixtures.Sandbox.entry(
                TestFixtures.Sandbox.systemPolicyDeny,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            lastAlert = detector.process(entry) ?? lastAlert
        }

        #expect(lastAlert != nil)
        #expect(lastAlert?.severity == .warning)
        #expect(lastAlert?.description.contains("wdavdaemon") == true)
    }

    @Test("groups Sandbox and System Policy entries by process independently")
    func groupsSandboxAndSystemPolicySeparately() {
        let detector = SandboxPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 3000)

        // 5 Sandbox: deny from Chrome -- below warning threshold
        for i in 0..<5 {
            let entry = TestFixtures.Sandbox.entry(
                TestFixtures.Sandbox.deny,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            _ = detector.process(entry)
        }

        // 5 System Policy: deny from wdavdaemon -- below warning threshold
        for i in 5..<10 {
            let entry = TestFixtures.Sandbox.entry(
                TestFixtures.Sandbox.systemPolicyDeny,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            let alert = detector.process(entry)
            #expect(alert == nil, "Different processes should be counted independently")
        }
    }

    @Test("accepts but does not count noise deny messages without Sandbox/SystemPolicy prefix")
    func acceptsButDoesNotCountNoiseMessages() {
        let detector = SandboxPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 4000)
        let entry = TestFixtures.Sandbox.entry(
            TestFixtures.Sandbox.noiseDeny,
            timestamp: t0
        )
        // Contains "deny(1)" so accepts() passes
        #expect(detector.accepts(entry))
        // But regex requires "Sandbox:" or "System Policy:" prefix — process() must not count it
        #expect(detector.process(entry) == nil)
        #expect(detector.groupCount == 0)
    }

    @Test("noise deny messages do not inflate real sandbox count")
    func noiseDoesNotInflateRealCount() {
        let detector = SandboxPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 5000)

        // Feed 5 real deny events (below warning threshold of 10)
        for i in 0..<5 {
            _ = detector.process(TestFixtures.Sandbox.entry(
                TestFixtures.Sandbox.deny,
                timestamp: t0.addingTimeInterval(Double(i))
            ))
        }

        // Flood with 30 noise messages
        for i in 0..<30 {
            _ = detector.process(TestFixtures.Sandbox.entry(
                TestFixtures.Sandbox.noiseDeny,
                timestamp: t0.addingTimeInterval(Double(i + 5))
            ))
        }

        // Feed 4 more real events (total real = 9, still below threshold of 10)
        for i in 0..<4 {
            let alert = detector.process(TestFixtures.Sandbox.entry(
                TestFixtures.Sandbox.deny,
                timestamp: t0.addingTimeInterval(Double(i + 35))
            ))
            #expect(alert == nil, "Noise should not push real count past warning threshold")
        }
    }
}
