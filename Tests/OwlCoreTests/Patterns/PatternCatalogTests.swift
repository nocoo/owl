import Testing
import Foundation
@testable import OwlCore

@Suite("PatternCatalog")
struct PatternCatalogTests {

    @Test("creates all detectors")
    func createsAllDetectors() {
        let detectors = PatternCatalog.makeAll()
        // 14 patterns, but P10 Jetsam has 2 detectors = 15 total
        #expect(detectors.count == 15)
    }

    @Test("all detector IDs are unique")
    func allIDsAreUnique() {
        let detectors = PatternCatalog.makeAll()
        let ids = detectors.map { $0.id }
        let uniqueIDs = Set(ids)
        #expect(uniqueIDs.count == ids.count)
    }

    @Test("all detectors are enabled by default")
    func allEnabledByDefault() {
        let detectors = PatternCatalog.makeAll()
        for detector in detectors {
            #expect(detector.isEnabled, "Detector \(detector.id) should be enabled by default")
        }
    }

    @Test("contains expected pattern IDs")
    func containsExpectedIDs() {
        let detectors = PatternCatalog.makeAll()
        let ids = Set(detectors.map { $0.id })

        let expectedIDs: Set<String> = [
            "thermal_throttling",
            "process_crash_loop",
            "apfs_flush_delay",
            "wifi_degradation",
            "sandbox_violation_storm",
            "sleep_assertion_leak",
            "process_crash_signal",
            "bluetooth_disconnect",
            "tcc_permission_storm",
            "jetsam_kill",
            "jetsam_kill_escalation",
            "app_hang",
            "network_failure",
            "usb_device_error",
            "darkwake_abnormal"
        ]

        #expect(ids == expectedIDs)
    }

    @Test("each detector can accept or reject a log entry")
    func detectorsAcceptOrReject() {
        let detectors = PatternCatalog.makeAll()
        let unrelatedEntry = TestFixtures.makeEntry(message: "completely unrelated log message")

        for detector in detectors {
            // Should not crash, and should reject unrelated
            #expect(!detector.accepts(unrelatedEntry), "Detector \(detector.id) should reject unrelated entry")
        }
    }

    @Test("makeAll returns fresh instances each call")
    func freshInstances() {
        let first = PatternCatalog.makeAll()
        let second = PatternCatalog.makeAll()

        // Disable one detector in first set
        first[0].isEnabled = false

        // Second set should be unaffected
        #expect(second[0].isEnabled)
    }
}
