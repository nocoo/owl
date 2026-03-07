import Testing
import Foundation
@testable import OwlCore

@Suite("P01 ThermalPattern")
struct ThermalPatternTests {

    let detector = ThermalPattern.makeDetector()

    @Test("has correct ID")
    func hasCorrectID() {
        #expect(detector.id == "thermal_throttling")
    }

    @Test("accepts thermal log entries")
    func acceptsThermalEntries() {
        let entry = TestFixtures.Thermal.entry(TestFixtures.Thermal.warning)
        #expect(detector.accepts(entry))
    }

    @Test("rejects unrelated log entries")
    func rejectsUnrelatedEntries() {
        let entry = TestFixtures.makeEntry(message: "some random kernel message")
        #expect(!detector.accepts(entry))
    }

    @Test("extracts power budget and triggers warning below 6000 mW")
    func triggersWarningBelow6000() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = t0.addingTimeInterval(6)

        // First reading enters pending (debounce = 5s)
        let entry1 = TestFixtures.Thermal.entry(TestFixtures.Thermal.warning, timestamp: t0)
        let alert1 = detector.process(entry1)
        #expect(alert1 == nil)
        #expect(detector.currentState == .pending)

        // Second reading after debounce triggers warning
        let entry2 = TestFixtures.Thermal.entry(TestFixtures.Thermal.warning, timestamp: t1)
        let alert2 = detector.process(entry2)
        #expect(alert2 != nil)
        #expect(alert2?.severity == .warning)
        #expect(detector.currentState == .warning)
    }

    @Test("triggers critical below 3000 mW immediately (bypasses debounce)")
    func triggersCriticalBelow3000() {
        let entry = TestFixtures.Thermal.entry(TestFixtures.Thermal.critical)
        let alert = detector.process(entry)
        #expect(alert != nil)
        #expect(alert?.severity == .critical)
        #expect(detector.currentState == .critical)
    }

    @Test("recovers when power budget exceeds 7000 mW")
    func recoversAbove7000() {
        // Drive to critical first
        let critEntry = TestFixtures.Thermal.entry(TestFixtures.Thermal.critical)
        _ = detector.process(critEntry)
        #expect(detector.currentState == .critical)

        // Recovery
        let recoveryEntry = TestFixtures.Thermal.entry(TestFixtures.Thermal.recovered)
        let alert = detector.process(recoveryEntry)
        #expect(alert != nil)
        #expect(alert?.severity == .info) // Recovery alert
        #expect(detector.currentState == .normal)
    }

    @Test("normal power budget does not trigger")
    func normalDoesNotTrigger() {
        let entry = TestFixtures.Thermal.entry(TestFixtures.Thermal.normal)
        let alert = detector.process(entry)
        #expect(alert == nil)
        #expect(detector.currentState == .normal)
    }

    @Test("alert contains correct title and suggestion")
    func alertContent() {
        let entry = TestFixtures.Thermal.entry(TestFixtures.Thermal.critical)
        let alert = detector.process(entry)
        #expect(alert?.title == L10n.tr(.alertThermalTitle))
        #expect(alert?.suggestion.contains("Activity Monitor") == true)
        #expect(alert?.description.contains("2500") == true)
    }
}
