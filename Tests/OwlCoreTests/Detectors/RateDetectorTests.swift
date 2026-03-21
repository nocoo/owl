import Foundation
import Testing
@testable import OwlCore

@Suite("RateDetector")
// swiftlint:disable:next type_body_length
struct RateDetectorTests {

    // MARK: - Helpers

    private func makeConfig(
        windowSeconds: Int = 60,
        warningRate: Int = 3,
        criticalRate: Int = 5,
        cooldownInterval: TimeInterval = 60,
        maxGroups: Int = 50
    ) -> RateConfig {
        RateConfig(
            id: "P02",
            regex: #"crash: (.+)"#,
            groupBy: .captureGroup,
            windowSeconds: windowSeconds,
            warningRate: warningRate,
            criticalRate: criticalRate,
            cooldownInterval: cooldownInterval,
            maxGroups: maxGroups,
            titleKey: .alertCrashLoopTitle,
            descriptionTemplateKey: .alertCrashLoopDesc("{key}", "{window}", "{count}"),
            suggestionKey: .alertCrashLoopSuggestion,
            acceptsFilter: "crash"
        )
    }

    private func makeGlobalConfig(
        warningRate: Int = 5,
        criticalRate: Int = 10
    ) -> RateConfig {
        RateConfig(
            id: "P12",
            regex: #"network error"#,
            groupBy: .global,
            windowSeconds: 60,
            warningRate: warningRate,
            criticalRate: criticalRate,
            cooldownInterval: 60,
            maxGroups: 1,
            titleKey: .alertNetworkTitle,
            descriptionTemplateKey: .alertNetworkDesc("{window}", "{count}"),
            suggestionKey: .alertNetworkSuggestion,
            acceptsFilter: "network error"
        )
    }

    private func makeEntry(
        message: String,
        timestamp: Date = Date()
    ) -> LogEntry {
        LogEntry(
            timestamp: timestamp,
            process: "ReportCrash",
            processID: 100,
            subsystem: "",
            category: "",
            messageType: "Error",
            eventMessage: message
        )
    }

    // MARK: - accepts()

    @Test func acceptsMatchingMessage() {
        let detector = RateDetector(config: makeConfig())
        let entry = makeEntry(message: "crash: com.example.app")
        #expect(detector.accepts(entry))
    }

    @Test func rejectsNonMatchingMessage() {
        let detector = RateDetector(config: makeConfig())
        let entry = makeEntry(message: "some unrelated log")
        #expect(!detector.accepts(entry))
    }

    // MARK: - Basic counting

    @Test func noAlertBelowWarningThreshold() {
        let detector = RateDetector(config: makeConfig(warningRate: 3))
        let t0 = Date()

        for i in 0..<2 {
            let alert = detector.process(makeEntry(
                message: "crash: com.example.app",
                timestamp: t0.addingTimeInterval(Double(i))
            ))
            #expect(alert == nil)
        }
    }

    @Test func warningAlertAtWarningThreshold() {
        let detector = RateDetector(config: makeConfig(warningRate: 3, criticalRate: 5))
        let t0 = Date()

        var lastAlert: Alert?
        for i in 0..<3 {
            lastAlert = detector.process(makeEntry(
                message: "crash: com.example.app",
                timestamp: t0.addingTimeInterval(Double(i))
            ))
        }

        #expect(lastAlert != nil)
        #expect(lastAlert?.severity == .warning)
        #expect(lastAlert?.detectorID == "P02")
    }

    @Test func criticalAlertAtCriticalThreshold() {
        let detector = RateDetector(config: makeConfig(warningRate: 3, criticalRate: 5, cooldownInterval: 0))
        let t0 = Date()

        var lastAlert: Alert?
        for i in 0..<5 {
            lastAlert = detector.process(makeEntry(
                message: "crash: com.example.app",
                timestamp: t0.addingTimeInterval(Double(i))
            ))
        }

        #expect(lastAlert != nil)
        #expect(lastAlert?.severity == .critical)
    }

    // MARK: - Grouped counting

    @Test func differentKeysCountedIndependently() {
        let detector = RateDetector(config: makeConfig(warningRate: 3))
        let t0 = Date()

        // 2 events for app1, 2 for app2 — neither hits threshold of 3
        for i in 0..<2 {
            let alert = detector.process(makeEntry(
                message: "crash: com.app1",
                timestamp: t0.addingTimeInterval(Double(i))
            ))
            #expect(alert == nil)
        }
        for i in 0..<2 {
            let alert = detector.process(makeEntry(
                message: "crash: com.app2",
                timestamp: t0.addingTimeInterval(Double(i + 2))
            ))
            #expect(alert == nil)
        }
    }

    @Test func specificKeyHitsThreshold() {
        let detector = RateDetector(config: makeConfig(warningRate: 3))
        let t0 = Date()

        // 1 event for app2
        _ = detector.process(makeEntry(message: "crash: com.app2", timestamp: t0))

        // 3 events for app1 — should trigger
        var lastAlert: Alert?
        for i in 0..<3 {
            lastAlert = detector.process(makeEntry(
                message: "crash: com.app1",
                timestamp: t0.addingTimeInterval(Double(i + 1))
            ))
        }

        #expect(lastAlert != nil)
        #expect(lastAlert?.severity == .warning)
    }

    // MARK: - Global mode (no grouping)

    @Test func globalModeCountsAllEventsTogther() {
        let detector = RateDetector(config: makeGlobalConfig(warningRate: 3))
        let t0 = Date()

        var lastAlert: Alert?
        for i in 0..<3 {
            lastAlert = detector.process(makeEntry(
                message: "network error occurred",
                timestamp: t0.addingTimeInterval(Double(i))
            ))
        }

        #expect(lastAlert != nil)
        #expect(lastAlert?.severity == .warning)
    }

    @Test func globalModeRejectsNonMatchingMessages() {
        let detector = RateDetector(config: makeGlobalConfig(warningRate: 3))
        let t0 = Date()

        // Feed messages that contain the acceptsFilter ("network error")
        // but do NOT match the full regex ("network error")
        // Actually the global config regex IS "network error", so let's use
        // a tighter regex to demonstrate the fix
        let config = RateConfig(
            id: "test_global",
            regex: #"network error: timeout"#,
            groupBy: .global,
            windowSeconds: 60,
            warningRate: 3,
            criticalRate: 10,
            cooldownInterval: 60,
            maxGroups: 1,
            titleKey: .alertNetworkTitle,
            descriptionTemplateKey: .alertNetworkDesc("{window}", "{count}"),
            suggestionKey: .alertNetworkSuggestion,
            acceptsFilter: "network"
        )
        let det = RateDetector(config: config)

        // These contain "network" but don't match "network error: timeout"
        for i in 0..<5 {
            let result = det.process(makeEntry(
                message: "network status: connected",
                timestamp: t0.addingTimeInterval(Double(i))
            ))
            #expect(result == nil)
        }
        // Should not have created any counter group
        #expect(det.groupCount == 0)

        // Now feed matching messages
        for i in 0..<3 {
            _ = det.process(makeEntry(
                message: "network error: timeout on port 443",
                timestamp: t0.addingTimeInterval(Double(i + 10))
            ))
        }
        #expect(det.groupCount == 1)
    }

    // MARK: - Cooldown

    @Test func cooldownPreventsRepeatedAlerts() {
        let detector = RateDetector(config: makeConfig(
            warningRate: 3,
            criticalRate: 10,
            cooldownInterval: 60
        ))
        let t0 = Date()

        // Trigger warning
        let alertCount = (0..<6).compactMap { i in
            detector.process(makeEntry(
                message: "crash: com.example.app",
                timestamp: t0.addingTimeInterval(Double(i))
            ))
        }.count

        // Should only get 1 warning alert (cooldown blocks subsequent)
        #expect(alertCount == 1)
    }

    @Test func cooldownExpiresAllowsNewAlert() {
        let detector = RateDetector(config: makeConfig(
            warningRate: 2,
            criticalRate: 100,
            cooldownInterval: 10
        ))
        let t0 = Date()

        // Trigger first warning
        _ = detector.process(makeEntry(message: "crash: com.app", timestamp: t0))
        let first = detector.process(makeEntry(
            message: "crash: com.app",
            timestamp: t0.addingTimeInterval(1)
        ))
        #expect(first != nil)

        // During cooldown — no alert
        let during = detector.process(makeEntry(
            message: "crash: com.app",
            timestamp: t0.addingTimeInterval(5)
        ))
        #expect(during == nil)

        // After cooldown expires (and window is still active)
        let after = detector.process(makeEntry(
            message: "crash: com.app",
            timestamp: t0.addingTimeInterval(12)
        ))
        // Count should still be above threshold, so new alert fires
        #expect(after != nil)
    }

    // MARK: - Window expiry resets count

    @Test func eventsExpireOutOfWindow() {
        let detector = RateDetector(config: makeConfig(
            windowSeconds: 10,
            warningRate: 3,
            cooldownInterval: 0
        ))
        let t0 = Date()

        // 2 events at t0
        _ = detector.process(makeEntry(message: "crash: com.app", timestamp: t0))
        _ = detector.process(makeEntry(message: "crash: com.app", timestamp: t0.addingTimeInterval(1)))

        // Jump to t0+15 — old events expired
        let late = detector.process(makeEntry(
            message: "crash: com.app",
            timestamp: t0.addingTimeInterval(15)
        ))
        // Only 1 event in window — below threshold
        #expect(late == nil)
    }

    // MARK: - LRU eviction (maxGroups)

    @Test func evictsLeastRecentlySeenGroup() {
        let detector = RateDetector(config: makeConfig(maxGroups: 3))
        let t0 = Date()

        // Fill 3 groups
        _ = detector.process(makeEntry(message: "crash: app1", timestamp: t0))
        _ = detector.process(makeEntry(message: "crash: app2", timestamp: t0.addingTimeInterval(1)))
        _ = detector.process(makeEntry(message: "crash: app3", timestamp: t0.addingTimeInterval(2)))

        // 4th group should evict the oldest (app1)
        _ = detector.process(makeEntry(message: "crash: app4", timestamp: t0.addingTimeInterval(3)))

        #expect(detector.groupCount <= 3)
    }

    // MARK: - tick() cleans up stale groups

    @Test func tickCleansUpStaleGroups() {
        let config = makeConfig(windowSeconds: 10, maxGroups: 50)
        let detector = RateDetector(config: config)
        let t0 = Date()

        _ = detector.process(makeEntry(message: "crash: stale.app", timestamp: t0))

        // Advance time well past 2x window
        detector.advanceTimeForTesting(to: t0.addingTimeInterval(25))
        let alerts = detector.tick()

        #expect(alerts.isEmpty)
        #expect(detector.groupCount == 0) // Stale group was cleaned up
    }

    // MARK: - Description template

    @Test func alertDescriptionContainsKeyAndCount() {
        let detector = RateDetector(config: makeConfig(warningRate: 2))
        let t0 = Date()

        _ = detector.process(makeEntry(message: "crash: com.test.app", timestamp: t0))
        let alert = detector.process(makeEntry(
            message: "crash: com.test.app",
            timestamp: t0.addingTimeInterval(1)
        ))

        #expect(alert != nil)
        #expect(alert?.description.contains("com.test.app") == true)
        #expect(alert?.description.contains("2") == true)
    }

    // MARK: - isEnabled flag

    @Test func isEnabledDefaultsToTrue() {
        let detector = RateDetector(config: makeConfig())
        #expect(detector.isEnabled)
    }

    @Test func isEnabledCanBeToggled() {
        let detector = RateDetector(config: makeConfig())
        detector.isEnabled = false
        #expect(!detector.isEnabled)
    }

    // MARK: - captureGroup mode regex validation

    @Test func captureGroupModeRejectsRegexMismatch() {
        // Config uses regex `crash: (.+)` with acceptsFilter "crash".
        // Messages containing "crash" pass accepts(), but if they
        // don't match the full regex, process() must NOT count them.
        let detector = RateDetector(config: makeConfig(warningRate: 3))
        let t0 = Date()

        for i in 0..<5 {
            let entry = makeEntry(
                message: "crash log rotation complete",
                timestamp: t0.addingTimeInterval(Double(i))
            )
            // Passes acceptsFilter ("crash") but fails regex (`crash: (.+)`)
            let alert = detector.process(entry)
            #expect(alert == nil, "Regex-failing message must not trigger alert")
        }

        // No counter group should have been created
        #expect(detector.groupCount == 0, "Regex-failing messages must not create counter groups")
    }

    @Test func captureGroupNoiseDoesNotInflateRealCount() {
        let detector = RateDetector(config: makeConfig(warningRate: 5))
        let t0 = Date()

        // Feed 2 real messages (below threshold)
        for i in 0..<2 {
            _ = detector.process(makeEntry(
                message: "crash: com.example.app",
                timestamp: t0.addingTimeInterval(Double(i))
            ))
        }

        // Feed 10 noise messages that pass acceptsFilter but fail regex
        for i in 0..<10 {
            _ = detector.process(makeEntry(
                message: "crash log rotation complete",
                timestamp: t0.addingTimeInterval(Double(i + 2))
            ))
        }

        // Feed 2 more real messages (total real = 4, still below 5)
        for i in 0..<2 {
            let alert = detector.process(makeEntry(
                message: "crash: com.example.app",
                timestamp: t0.addingTimeInterval(Double(i + 12))
            ))
            #expect(alert == nil, "Noise should not inflate count past threshold")
        }

        // Only the real key group should exist
        #expect(detector.groupCount == 1)
    }
}
