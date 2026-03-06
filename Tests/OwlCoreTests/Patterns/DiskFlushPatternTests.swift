import Testing
import Foundation
@testable import OwlCore

@Suite("P03 DiskFlushPattern")
struct DiskFlushPatternTests {

    let detector = DiskFlushPattern.makeDetector()

    @Test("has correct ID")
    func hasCorrectID() {
        #expect(detector.id == "apfs_flush_delay")
    }

    @Test("accepts tx_flush log entries")
    func acceptsDiskFlushEntries() {
        let entry = TestFixtures.DiskFlush.entry(TestFixtures.DiskFlush.warning)
        #expect(detector.accepts(entry))
    }

    @Test("rejects unrelated log entries")
    func rejectsUnrelatedEntries() {
        let entry = TestFixtures.makeEntry(message: "kernel: some other message")
        #expect(!detector.accepts(entry))
    }

    @Test("triggers warning when flush exceeds 10 ms after debounce")
    func triggersWarningAbove10ms() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = t0.addingTimeInterval(4)

        // First reading enters pending (debounce = 3s)
        let entry1 = TestFixtures.DiskFlush.entry(TestFixtures.DiskFlush.warning, timestamp: t0)
        let alert1 = detector.process(entry1)
        #expect(alert1 == nil)
        #expect(detector.currentState == .pending)

        // After debounce
        let entry2 = TestFixtures.DiskFlush.entry(TestFixtures.DiskFlush.warning, timestamp: t1)
        let alert2 = detector.process(entry2)
        #expect(alert2 != nil)
        #expect(alert2?.severity == .warning)
    }

    @Test("triggers critical when flush exceeds 100 ms")
    func triggersCriticalAbove100ms() {
        let entry = TestFixtures.DiskFlush.entry(TestFixtures.DiskFlush.critical)
        let alert = detector.process(entry)
        #expect(alert != nil)
        #expect(alert?.severity == .critical)
    }

    @Test("recovers when flush drops below 5 ms")
    func recoversBelow5ms() {
        // Drive to critical
        let critEntry = TestFixtures.DiskFlush.entry(TestFixtures.DiskFlush.critical)
        _ = detector.process(critEntry)
        #expect(detector.currentState == .critical)

        // Recovery
        let normalEntry = TestFixtures.DiskFlush.entry(TestFixtures.DiskFlush.normal)
        let alert = detector.process(normalEntry)
        #expect(alert != nil)
        #expect(alert?.severity == .info) // Recovery
        #expect(detector.currentState == .normal)
    }

    @Test("extracts correct value from flush message")
    func extractsCorrectValue() {
        let entry = TestFixtures.DiskFlush.entry(TestFixtures.DiskFlush.critical)
        _ = detector.process(entry)
        #expect(detector.lastValue == 150.456)
    }
}
