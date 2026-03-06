import Foundation
import Testing
@testable import OwlCore

// MARK: - Integration: Full Pipeline E2E

@Suite("Integration - End to End", .timeLimit(.minutes(1)))
struct EndToEndTests {

    // MARK: - Crash Loop Detection

    @Test func crashLoopDetectionEndToEnd() async {
        let pipeline = DetectorPipeline()
        let manager = AlertStateManager(debounceInterval: 0)
        let now = Date()

        // P02 CrashLoop: warning=5 events in 60s window
        for idx in 0..<5 {
            let entry = TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.quit,
                timestamp: now.addingTimeInterval(Double(idx))
            )
            let alerts = await pipeline.process(entry)
            for alert in alerts {
                manager.receive(alert)
            }
        }

        manager.performMaintenance(at: now.addingTimeInterval(6))

        let active = manager.activeAlerts.filter {
            $0.detectorID == "process_crash_loop"
        }
        #expect(active.count == 1)
        #expect(active.first?.severity == .warning)
    }

    @Test func crashLoopEscalatesToCritical() async {
        let pipeline = DetectorPipeline()
        let manager = AlertStateManager(debounceInterval: 0)
        let now = Date()

        // P02: critical=20 events in 60s window
        for idx in 0..<20 {
            let entry = TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.quit,
                timestamp: now.addingTimeInterval(Double(idx))
            )
            let alerts = await pipeline.process(entry)
            for alert in alerts {
                manager.receive(alert)
            }
            manager.performMaintenance(
                at: now.addingTimeInterval(Double(idx) + 0.1)
            )
        }

        let active = manager.activeAlerts.filter {
            $0.detectorID == "process_crash_loop"
        }
        #expect(active.count == 1)
        #expect(active.first?.severity == .critical)
    }

    // MARK: - Network Failure Detection

    @Test func networkFailureEndToEnd() async {
        let pipeline = DetectorPipeline()
        let manager = AlertStateManager(debounceInterval: 0)
        let now = Date()

        // P12: global rate, warning=10 events in 60s window
        for idx in 0..<10 {
            let entry = TestFixtures.Network.entry(
                TestFixtures.Network.failed,
                timestamp: now.addingTimeInterval(Double(idx))
            )
            let alerts = await pipeline.process(entry)
            for alert in alerts {
                manager.receive(alert)
            }
        }

        manager.performMaintenance(at: now.addingTimeInterval(11))

        let active = manager.activeAlerts.filter {
            $0.detectorID == "network_failure"
        }
        #expect(active.count == 1)
        #expect(active.first?.severity == .warning)
    }

    // MARK: - Jetsam Hybrid Detection

    @Test func jetsamSingleKillTriggersImmediateWarning() async {
        let pipeline = DetectorPipeline()
        let manager = AlertStateManager(debounceInterval: 0)
        let now = Date()

        // P10: Single kill -> immediate warning (threshold, debounce=0)
        let entry = TestFixtures.Jetsam.entry(
            TestFixtures.Jetsam.kill,
            timestamp: now
        )
        let alerts = await pipeline.process(entry)
        for alert in alerts {
            manager.receive(alert)
        }
        manager.performMaintenance(at: now.addingTimeInterval(0.1))

        let active = manager.activeAlerts.filter {
            $0.detectorID == "jetsam_kill"
        }
        #expect(active.count == 1)
        #expect(active.first?.severity == .warning)
    }

    @Test func jetsamEscalatesToCriticalViaRateDetector() async {
        let pipeline = DetectorPipeline()
        let manager = AlertStateManager(debounceInterval: 0)
        let now = Date()

        // P10 rate: 3 kills in 5 min -> critical
        for idx in 0..<3 {
            let entry = TestFixtures.Jetsam.entry(
                TestFixtures.Jetsam.kill,
                timestamp: now.addingTimeInterval(Double(idx) * 10)
            )
            let alerts = await pipeline.process(entry)
            for alert in alerts {
                manager.receive(alert)
            }
            manager.performMaintenance(
                at: now.addingTimeInterval(Double(idx) * 10 + 0.1)
            )
        }

        let critical = manager.activeAlerts.filter {
            $0.detectorID == "jetsam_kill_escalation"
                && $0.severity == .critical
        }
        #expect(critical.count == 1)
    }

    // MARK: - Multiple Patterns Concurrently

    @Test func multiplePatternsConcurrently() async {
        let pipeline = DetectorPipeline()
        let manager = AlertStateManager(debounceInterval: 0)
        let now = Date()

        // Feed crash loop + network failures simultaneously
        for idx in 0..<10 {
            let ts = now.addingTimeInterval(Double(idx))
            let crash = TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.quit, timestamp: ts
            )
            let network = TestFixtures.Network.entry(
                TestFixtures.Network.failed, timestamp: ts
            )
            let alerts1 = await pipeline.process(crash)
            let alerts2 = await pipeline.process(network)
            for alert in alerts1 + alerts2 {
                manager.receive(alert)
            }
        }

        manager.performMaintenance(at: now.addingTimeInterval(11))

        let crashAlerts = manager.activeAlerts.filter {
            $0.detectorID == "process_crash_loop"
        }
        let networkAlerts = manager.activeAlerts.filter {
            $0.detectorID == "network_failure"
        }
        #expect(crashAlerts.count == 1)
        #expect(networkAlerts.count == 1)
        #expect(manager.currentSeverity == .warning)
    }

    // MARK: - Disabled Detector

    @Test func disabledDetectorSkipsProcessing() async {
        let pipeline = DetectorPipeline()
        let manager = AlertStateManager(debounceInterval: 0)
        let now = Date()

        await pipeline.setEnabled(
            false, forDetectorID: "process_crash_loop"
        )

        // Send 5 crash events (normally triggers warning)
        for idx in 0..<5 {
            let entry = TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.quit,
                timestamp: now.addingTimeInterval(Double(idx))
            )
            let alerts = await pipeline.process(entry)
            for alert in alerts {
                manager.receive(alert)
            }
        }

        manager.performMaintenance(at: now.addingTimeInterval(6))

        let active = manager.activeAlerts.filter {
            $0.detectorID == "process_crash_loop"
        }
        #expect(active.isEmpty)
    }

    // MARK: - Alert Lifecycle

    @Test func alertLifecyclePendingToActiveToExpired() async {
        let pipeline = DetectorPipeline()
        let manager = AlertStateManager(debounceInterval: 5)
        let now = Date()

        // Trigger crash loop warning
        for idx in 0..<5 {
            let entry = TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.quit,
                timestamp: now.addingTimeInterval(Double(idx))
            )
            let alerts = await pipeline.process(entry)
            for alert in alerts {
                manager.receive(alert)
            }
        }

        // Immediately: should be in pending
        manager.performMaintenance(at: now.addingTimeInterval(5))
        let pending = manager.pendingAlerts.filter {
            $0.detectorID == "process_crash_loop"
        }
        #expect(pending.count == 1)

        // After debounce: should move to active
        manager.performMaintenance(at: now.addingTimeInterval(11))
        let active = manager.activeAlerts.filter {
            $0.detectorID == "process_crash_loop"
        }
        #expect(active.count == 1)
        #expect(manager.currentSeverity == .warning)

        // After TTL (warning=300s): should expire to history
        manager.performMaintenance(at: now.addingTimeInterval(320))
        let history = manager.alertHistory.filter {
            $0.detectorID == "process_crash_loop"
        }
        #expect(history.count == 1)
        #expect(manager.activeAlerts.isEmpty)
        #expect(manager.currentSeverity == .normal)
    }

    // MARK: - State Detector Tick (Leak Detection)

    @Test func tickDetectsStateLeaks() async {
        let pipeline = DetectorPipeline()
        let manager = AlertStateManager(debounceInterval: 0)
        let now = Date()

        // P06: create sleep assertion without release
        let created = TestFixtures.SleepAssertion.entry(
            TestFixtures.SleepAssertion.created,
            timestamp: now
        )
        _ = await pipeline.process(created)

        // Advance StateDetector's internal clock by sending
        // a released event with a bogus ID (won't pair, just
        // updates currentTime). Message must contain acceptsFilter.
        let future = now.addingTimeInterval(1801)
        let bogusRelease = #"Released InternalPreventSleep "bogus" 00000000 id:0xDEADBEEF"#
        let laterEntry = TestFixtures.SleepAssertion.entry(
            bogusRelease,
            timestamp: future
        )
        _ = await pipeline.process(laterEntry)

        // Now tick should detect the leaked assertion
        let tickAlerts = await pipeline.tick()

        for alert in tickAlerts {
            manager.receive(alert)
        }
        manager.performMaintenance(at: future)

        let active = manager.activeAlerts.filter {
            $0.detectorID == "sleep_assertion_leak"
        }
        #expect(active.count == 1)
        #expect(active.first?.severity == .warning)
    }

    // MARK: - Severity Aggregation

    @Test func currentSeverityReflectsWorstActiveAlert() async {
        let pipeline = DetectorPipeline()
        let manager = AlertStateManager(debounceInterval: 0)
        let now = Date()

        #expect(manager.currentSeverity == .normal)

        // Trigger crash loop warning (5 events)
        for idx in 0..<5 {
            let entry = TestFixtures.CrashLoop.entry(
                TestFixtures.CrashLoop.quit,
                timestamp: now.addingTimeInterval(Double(idx))
            )
            let alerts = await pipeline.process(entry)
            for alert in alerts {
                manager.receive(alert)
            }
        }
        manager.performMaintenance(at: now.addingTimeInterval(6))
        #expect(manager.currentSeverity == .warning)

        // Trigger jetsam critical (3 kills)
        for idx in 0..<3 {
            let entry = TestFixtures.Jetsam.entry(
                TestFixtures.Jetsam.kill,
                timestamp: now.addingTimeInterval(
                    Double(idx) * 10 + 10
                )
            )
            let alerts = await pipeline.process(entry)
            for alert in alerts {
                manager.receive(alert)
            }
            manager.performMaintenance(
                at: now.addingTimeInterval(
                    Double(idx) * 10 + 10.1
                )
            )
        }

        #expect(manager.currentSeverity == .critical)
    }
}

// MARK: - Full Path via LogStreamReader

@Suite("Integration - Stream to Pipeline", .timeLimit(.minutes(1)))
struct StreamToPipelineTests {

    @Test func logStreamReaderToPipelineToAlerts() async {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            predicate: "process == 'launchservicesd'",
            autoRestart: false,
            processFactory: factory
        )

        await reader.start()
        try? await Task.sleep(nanoseconds: 50_000_000)

        guard let mockProcess = factory.lastProcess else {
            #expect(Bool(false), "Process should have been created")
            return
        }

        let pipeline = DetectorPipeline()
        let manager = AlertStateManager(debounceInterval: 0)

        let now = Date()
        for idx in 0..<5 {
            let ts = now.addingTimeInterval(Double(idx))
            let json = makeLogJSON(
                message: TestFixtures.CrashLoop.quit,
                process: "launchservicesd",
                timestamp: ts
            )
            mockProcess.writeLine(json)
        }

        // Close stdout so the stream finishes after all lines are read
        mockProcess.closeStdout()

        // Consume all entries from the stream
        let entries = await reader.entries
        for await entry in entries {
            let alerts = await pipeline.process(entry)
            for alert in alerts {
                manager.receive(alert)
            }
        }

        manager.performMaintenance(at: now.addingTimeInterval(6))

        let active = manager.activeAlerts.filter {
            $0.detectorID == "process_crash_loop"
        }
        #expect(active.count == 1)

        await reader.stop()
    }

    // MARK: - Helpers

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSxxxx"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private func makeLogJSON(
        message: String,
        process: String = "kernel",
        timestamp: Date = Date(),
        subsystem: String = "",
        category: String = ""
    ) -> String {
        let ts = Self.timestampFormatter.string(from: timestamp)
        let escaped = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        // swiftlint:disable:next line_length
        return "{\"traceID\":1,\"eventMessage\":\"\(escaped)\",\"processID\":0,\"processImagePath\":\"/usr/libexec/\(process)\",\"timestamp\":\"\(ts)\",\"subsystem\":\"\(subsystem)\",\"category\":\"\(category)\",\"messageType\":\"Default\"}"
    }
}
