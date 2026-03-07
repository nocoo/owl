import Testing
import Foundation
@testable import OwlCore

@Suite("DetectorPipeline")
struct DetectorPipelineTests {

    // MARK: - Helpers

    private func makeEntry(
        message: String,
        timestamp: Date = Date(timeIntervalSince1970: 1000)
    ) -> LogEntry {
        TestFixtures.makeEntry(message: message, timestamp: timestamp)
    }

    // MARK: - Initialization

    @Test("initializes with detectors from PatternCatalog")
    func initializesWithCatalog() async {
        let pipeline = DetectorPipeline()
        let count = await pipeline.detectorCount
        #expect(count == 15)
    }

    @Test("initializes with custom detectors")
    func initializesWithCustomDetectors() async {
        let detector = ThermalPattern.makeDetector()
        let pipeline = DetectorPipeline(detectors: [detector])
        let count = await pipeline.detectorCount
        #expect(count == 1)
    }

    // MARK: - Processing

    @Test("dispatches entry to matching detector and returns alert")
    func dispatchesToMatchingDetector() async {
        // Use a ThresholdDetector with zero debounce to get immediate alert
        let detector = JetsamPattern.makeDetector()
        let pipeline = DetectorPipeline(detectors: [detector])

        let entry = TestFixtures.Jetsam.entry(
            TestFixtures.Jetsam.kill,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        let alerts = await pipeline.process(entry)
        #expect(alerts.count == 1)
        #expect(alerts[0].severity == .warning)
    }

    @Test("returns empty array when no detector matches")
    func returnsEmptyForNoMatch() async {
        let detector = ThermalPattern.makeDetector()
        let pipeline = DetectorPipeline(detectors: [detector])

        let entry = makeEntry(message: "completely unrelated log message")
        let alerts = await pipeline.process(entry)
        #expect(alerts.isEmpty)
    }

    @Test("skips disabled detectors")
    func skipsDisabledDetectors() async {
        let detector = JetsamPattern.makeDetector()
        let pipeline = DetectorPipeline(detectors: [detector])

        await pipeline.setEnabled(false, forDetectorID: "jetsam_kill")

        let entry = TestFixtures.Jetsam.entry(
            TestFixtures.Jetsam.kill,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        let alerts = await pipeline.process(entry)
        #expect(alerts.isEmpty)
    }

    @Test("dispatches to multiple matching detectors")
    func dispatchesToMultipleDetectors() async {
        // Both Jetsam detectors accept the same log entry
        let primary = JetsamPattern.makeDetector()
        let escalation = JetsamPattern.makeEscalationDetector()
        let pipeline = DetectorPipeline(detectors: [primary, escalation])

        let entry = TestFixtures.Jetsam.entry(
            TestFixtures.Jetsam.kill,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        let alerts = await pipeline.process(entry)
        // Primary triggers immediately (zero debounce), escalation needs 3+ events
        #expect(alerts.count == 1)
        #expect(alerts[0].detectorID == "jetsam_kill")
    }

    // MARK: - Enable/Disable

    @Test("can enable and disable detectors by ID")
    func enableDisableByID() async {
        let detector = ThermalPattern.makeDetector()
        let pipeline = DetectorPipeline(detectors: [detector])

        let enabled1 = await pipeline.isEnabled(detectorID: "thermal_throttling")
        #expect(enabled1 == true)

        await pipeline.setEnabled(false, forDetectorID: "thermal_throttling")
        let enabled2 = await pipeline.isEnabled(detectorID: "thermal_throttling")
        #expect(enabled2 == false)

        await pipeline.setEnabled(true, forDetectorID: "thermal_throttling")
        let enabled3 = await pipeline.isEnabled(detectorID: "thermal_throttling")
        #expect(enabled3 == true)
    }

    @Test("setEnabled for unknown ID is a no-op")
    func setEnabledUnknownID() async {
        let pipeline = DetectorPipeline(detectors: [])
        // Should not crash
        await pipeline.setEnabled(false, forDetectorID: "nonexistent")
    }

    // MARK: - Tick

    @Test("tick calls tick on all detectors")
    func tickCallsAllDetectors() async {
        // Use a StateDetector that produces alerts on tick
        let detector = SleepAssertionPattern.makeDetector()
        let pipeline = DetectorPipeline(detectors: [detector])

        // Create an assertion that won't be released (leak)
        let createEntry = TestFixtures.SleepAssertion.entry(
            TestFixtures.SleepAssertion.created,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
        _ = await pipeline.process(createEntry)

        // Advance detector time to 2 hours later (→ critical leak)
        detector.advanceTimeForTesting(
            to: Date(timeIntervalSince1970: 1000 + 7200)
        )

        let tickAlerts = await pipeline.tick()
        #expect(!tickAlerts.isEmpty)
    }

    @Test("tick returns empty when no leaks detected")
    func tickReturnsEmptyWhenClean() async {
        let detector = ThermalPattern.makeDetector()
        let pipeline = DetectorPipeline(detectors: [detector])

        let alerts = await pipeline.tick()
        #expect(alerts.isEmpty)
    }

    // MARK: - Detector IDs

    @Test("returns all detector IDs")
    func returnsAllDetectorIDs() async {
        let pipeline = DetectorPipeline()
        let ids = await pipeline.detectorIDs
        #expect(ids.count == 15)
        #expect(ids.contains("thermal_throttling"))
        #expect(ids.contains("jetsam_kill_escalation"))
    }

    // MARK: - Start Time Filtering

    @Test("drops entries with timestamps before pipeline start time")
    func dropsEntriesBeforeStartTime() async {
        let detector = JetsamPattern.makeDetector()
        let startTime = Date(timeIntervalSince1970: 2000)
        let pipeline = DetectorPipeline(
            detectors: [detector], startTime: startTime
        )

        // Entry before start time — should be ignored
        let oldEntry = TestFixtures.Jetsam.entry(
            TestFixtures.Jetsam.kill,
            timestamp: Date(timeIntervalSince1970: 1999)
        )
        let alerts1 = await pipeline.process(oldEntry)
        #expect(alerts1.isEmpty)

        // Entry at start time — should be processed
        let currentEntry = TestFixtures.Jetsam.entry(
            TestFixtures.Jetsam.kill,
            timestamp: Date(timeIntervalSince1970: 2000)
        )
        let alerts2 = await pipeline.process(currentEntry)
        #expect(alerts2.count == 1)
    }

    @Test("processBatch drops entries before start time")
    func processBatchDropsOldEntries() async {
        let detector = JetsamPattern.makeDetector()
        let startTime = Date(timeIntervalSince1970: 2000)
        let pipeline = DetectorPipeline(
            detectors: [detector], startTime: startTime
        )

        let entries = [
            TestFixtures.Jetsam.entry(
                TestFixtures.Jetsam.kill,
                timestamp: Date(timeIntervalSince1970: 1500)
            ),
            TestFixtures.Jetsam.entry(
                TestFixtures.Jetsam.kill,
                timestamp: Date(timeIntervalSince1970: 1999)
            ),
            TestFixtures.Jetsam.entry(
                TestFixtures.Jetsam.kill,
                timestamp: Date(timeIntervalSince1970: 2001)
            ),
        ]
        let alerts = await pipeline.processBatch(entries)
        // Only the last entry (after start time) should produce an alert
        #expect(alerts.count == 1)
    }

    @Test("test init uses distantPast so all entries pass")
    func testInitAllowsAllEntries() async {
        let detector = JetsamPattern.makeDetector()
        let pipeline = DetectorPipeline(detectors: [detector])

        let entry = TestFixtures.Jetsam.entry(
            TestFixtures.Jetsam.kill,
            timestamp: Date(timeIntervalSince1970: 1)
        )
        let alerts = await pipeline.process(entry)
        #expect(alerts.count == 1)
    }
}
