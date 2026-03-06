import Testing
import Foundation
@testable import OwlCore

@Suite("P13 USBPattern")
struct USBPatternTests {

    @Test("has correct ID")
    func hasCorrectID() {
        let detector = USBPattern.makeDetector()
        #expect(detector.id == "usb_device_error")
    }

    @Test("accepts abortGated log entries")
    func acceptsAbortEntries() {
        let detector = USBPattern.makeDetector()
        let entry = TestFixtures.USB.entry(TestFixtures.USB.abort)
        #expect(detector.accepts(entry))
    }

    @Test("rejects unrelated kernel entries")
    func rejectsUnrelatedEntries() {
        let detector = USBPattern.makeDetector()
        let entry = TestFixtures.makeEntry(message: "kernel: USB device attached")
        #expect(!detector.accepts(entry))
    }

    @Test("triggers warning after 5 abort events from same device")
    func triggersWarningAt5() {
        let detector = USBPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        for i in 0..<4 {
            let entry = TestFixtures.USB.entry(
                TestFixtures.USB.abort,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            #expect(detector.process(entry) == nil)
        }

        let entry5 = TestFixtures.USB.entry(
            TestFixtures.USB.abort,
            timestamp: t0.addingTimeInterval(4)
        )
        let alert = detector.process(entry5)
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
    }

    @Test("groups by device ID")
    func groupsByDeviceID() {
        let detector = USBPattern.makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        // 5 aborts from device 0x12345678
        for i in 0..<5 {
            let entry = TestFixtures.USB.entry(
                TestFixtures.USB.abort,
                timestamp: t0.addingTimeInterval(Double(i))
            )
            _ = detector.process(entry)
        }

        // Different device should not trigger
        let otherAbort = "AppleUSBHostController@02000000: IOUSBHostPipe::abortGated: device 0xAABBCCDD, endpoint 0x02"
        let entry = TestFixtures.USB.entry(
            otherAbort,
            timestamp: t0.addingTimeInterval(5)
        )
        let alert = detector.process(entry)
        #expect(alert == nil, "Different device at count 1 should not trigger")
    }
}
