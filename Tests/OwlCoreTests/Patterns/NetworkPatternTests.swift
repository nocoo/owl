import Testing
import Foundation
@testable import OwlCore

@Suite("P12 NetworkPattern")
struct NetworkPatternTests {

    @Test("has correct ID")
    func hasCorrectID() {
        let detector = NetworkPattern.makeDetector()
        #expect(detector.id == "network_failure")
    }

    @Test("accepts network failure log entries")
    func acceptsFailureEntries() {
        let detector = NetworkPattern.makeDetector()
        let entry = TestFixtures.Network.entry(TestFixtures.Network.failed)
        #expect(detector.accepts(entry))
    }

    @Test("rejects unrelated network entries")
    func rejectsUnrelatedEntries() {
        let detector = NetworkPattern.makeDetector()
        let entry = TestFixtures.makeEntry(
            message: "nw_connection established",
            process: "nsurlsessiond"
        )
        #expect(!detector.accepts(entry))
    }

    @Test("triggers warning after 10 failures globally")
    func triggersWarningAt10() {
        let detector = NetworkPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        for i in 0..<9 {
            let entry = TestFixtures.Network.entry(
                TestFixtures.Network.failed,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            #expect(detector.process(entry) == nil)
        }

        let entry10 = TestFixtures.Network.entry(
            TestFixtures.Network.failed,
            timestamp: t0.addingTimeInterval(9)
        )
        let alert = detector.process(entry10)
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
    }

    @Test("escalates to critical after 30 failures")
    func escalatesToCriticalAt30() {
        let detector = NetworkPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        var alerts: [Alert] = []
        for i in 0..<30 {
            let entry = TestFixtures.Network.entry(
                TestFixtures.Network.failed,
                timestamp: t0.addingTimeInterval(Double(i) * 0.5)
            )
            if let alert = detector.process(entry) {
                alerts.append(alert)
            }
        }

        #expect(alerts.count == 2)
        #expect(alerts[0].severity == .warning)
        #expect(alerts[1].severity == .critical)
    }

    @Test("uses global grouping (no per-process grouping)")
    func usesGlobalGrouping() {
        let detector = NetworkPattern.makeDetector()
        #expect(detector.groupCount == 0)

        let t0 = Date(timeIntervalSince1970: 1000)
        let entry = TestFixtures.Network.entry(
            TestFixtures.Network.failed,
            timestamp: t0
        )
        _ = detector.process(entry)

        // Only one group key (global)
        #expect(detector.groupCount == 1)
    }
}
