import Testing
import Foundation
@testable import OwlCore

@Suite("P04 WiFiPattern")
struct WiFiPatternTests {

    let detector = WiFiPattern.makeDetector()

    @Test("has correct ID")
    func hasCorrectID() {
        #expect(detector.id == "wifi_degradation")
    }

    @Test("accepts LQM log entries")
    func acceptsLQMEntries() {
        let entry = TestFixtures.WiFi.entry(TestFixtures.WiFi.weak)
        #expect(detector.accepts(entry))
    }

    @Test("rejects unrelated entries")
    func rejectsUnrelatedEntries() {
        let entry = TestFixtures.makeEntry(message: "airportd: scanning for networks")
        #expect(!detector.accepts(entry))
    }

    @Test("triggers warning when RSSI below -70 after debounce")
    func triggersWarningBelow70() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = t0.addingTimeInterval(11)

        // First reading enters pending (debounce = 10s)
        let entry1 = TestFixtures.WiFi.entry(TestFixtures.WiFi.weak, timestamp: t0)
        let alert1 = detector.process(entry1)
        #expect(alert1 == nil)
        #expect(detector.currentState == .pending)

        // After debounce
        let entry2 = TestFixtures.WiFi.entry(TestFixtures.WiFi.weak, timestamp: t1)
        let alert2 = detector.process(entry2)
        #expect(alert2 != nil)
        #expect(alert2?.severity == .warning)
    }

    @Test("triggers critical when RSSI below -80")
    func triggersCriticalBelow80() {
        let entry = TestFixtures.WiFi.entry(TestFixtures.WiFi.veryWeak)
        let alert = detector.process(entry)
        #expect(alert != nil)
        #expect(alert?.severity == .critical)
    }

    @Test("recovers when RSSI above -65")
    func recoversAbove65() {
        // Drive to critical
        let critEntry = TestFixtures.WiFi.entry(TestFixtures.WiFi.veryWeak)
        _ = detector.process(critEntry)
        #expect(detector.currentState == .critical)

        // Recovery
        let goodEntry = TestFixtures.WiFi.entry(TestFixtures.WiFi.good)
        let alert = detector.process(goodEntry)
        #expect(alert != nil)
        #expect(alert?.severity == .info)
        #expect(detector.currentState == .normal)
    }

    @Test("good signal does not trigger")
    func goodSignalNoTrigger() {
        let entry = TestFixtures.WiFi.entry(TestFixtures.WiFi.good)
        let alert = detector.process(entry)
        #expect(alert == nil)
        #expect(detector.currentState == .normal)
    }

    @Test("extracts correct RSSI value")
    func extractsCorrectRSSI() {
        let entry = TestFixtures.WiFi.entry(TestFixtures.WiFi.weak)
        _ = detector.process(entry)
        #expect(detector.lastValue == -75)
    }
}
