import Testing
import Foundation
@testable import OwlCore

@Suite("P08 BluetoothPattern")
struct BluetoothPatternTests {

    @Test("has correct ID")
    func hasCorrectID() {
        let detector = BluetoothPattern.makeDetector()
        #expect(detector.id == "bluetooth_disconnect")
    }

    @Test("accepts disconnect log entries")
    func acceptsDisconnectEntries() {
        let detector = BluetoothPattern.makeDetector()
        let entry = TestFixtures.Bluetooth.entry(TestFixtures.Bluetooth.disconnect)
        #expect(detector.accepts(entry))
    }

    @Test("rejects unrelated entries")
    func rejectsUnrelatedEntries() {
        let detector = BluetoothPattern.makeDetector()
        let entry = TestFixtures.makeEntry(message: "bluetoothd: scanning")
        #expect(!detector.accepts(entry))
    }

    @Test("triggers warning after 3 disconnects from same device")
    func triggersWarningAt3() {
        let detector = BluetoothPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        for i in 0..<2 {
            let entry = TestFixtures.Bluetooth.entry(
                TestFixtures.Bluetooth.disconnect,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            #expect(detector.process(entry) == nil)
        }

        let entry3 = TestFixtures.Bluetooth.entry(
            TestFixtures.Bluetooth.disconnect,
            timestamp: t0.addingTimeInterval(2)
        )
        let alert = detector.process(entry3)
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
    }

    @Test("groups by MAC address")
    func groupsByMAC() {
        let detector = BluetoothPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        // 3 disconnects from one device
        for i in 0..<3 {
            let entry = TestFixtures.Bluetooth.entry(
                TestFixtures.Bluetooth.disconnect,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            _ = detector.process(entry)
        }

        // Different device should not trigger
        let otherDisconnect = #"Device disconnected - "Mouse" (11:22:33:44:55:66), reason: 0x13"#
        let entry = TestFixtures.Bluetooth.entry(
            otherDisconnect,
            timestamp: t0.addingTimeInterval(3)
        )
        let alert = detector.process(entry)
        #expect(alert == nil)
    }

    @Test("accepts but does not count noise disconnect messages without MAC")
    func acceptsButDoesNotCountNoiseMessages() {
        let detector = BluetoothPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)
        let entry = TestFixtures.Bluetooth.entry(
            TestFixtures.Bluetooth.noiseDisconnect,
            timestamp: t0
        )
        #expect(detector.accepts(entry))
        #expect(detector.process(entry) == nil)
        #expect(detector.groupCount == 0)
    }

    @Test("noise disconnect messages do not inflate real disconnect count")
    func noiseDoesNotInflateRealCount() {
        let detector = BluetoothPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        // Feed 1 real disconnect (below warning threshold of 3)
        _ = detector.process(TestFixtures.Bluetooth.entry(
            TestFixtures.Bluetooth.disconnect,
            timestamp: t0
        ))

        // Flood with 10 noise messages
        for i in 0..<10 {
            _ = detector.process(TestFixtures.Bluetooth.entry(
                TestFixtures.Bluetooth.noiseDisconnect,
                timestamp: t0.addingTimeInterval(Double(i + 1))
            ))
        }

        // Feed 1 more real event (total real = 2, still below threshold of 3)
        let alert = detector.process(TestFixtures.Bluetooth.entry(
            TestFixtures.Bluetooth.disconnect,
            timestamp: t0.addingTimeInterval(11)
        ))
        #expect(alert == nil, "Noise should not push real count past warning threshold")
    }
}
