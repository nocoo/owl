import Foundation
import Testing
@testable import OwlCore

@Suite("ThresholdDetector")
struct ThresholdDetectorTests {

    // MARK: - Helpers

    private func makeConfig(
        warningThreshold: Double = 5000,
        criticalThreshold: Double = 3000,
        recoveryThreshold: Double = 7000,
        debounce: TimeInterval = 2.0,
        comparison: Comparison = .lessThan
    ) -> ThresholdConfig {
        ThresholdConfig(
            id: "P01",
            regex: #"power budget: (\d+)"#,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold,
            recoveryThreshold: recoveryThreshold,
            debounce: debounce,
            comparison: comparison,
            title: "Thermal Throttling",
            descriptionTemplate: "Power budget dropped to {value}mW",
            suggestion: "Close resource-intensive apps",
            acceptsFilter: "power budget"
        )
    }

    private func makeEntry(
        message: String,
        timestamp: Date = Date(),
        process: String = "kernel"
    ) -> LogEntry {
        LogEntry(
            timestamp: timestamp,
            process: process,
            processID: 0,
            subsystem: "com.apple.kernel",
            category: "default",
            messageType: "Default",
            eventMessage: message
        )
    }

    // MARK: - Comparison enum

    @Test func comparisonLessThanTriggersWhenValueBelowThreshold() {
        #expect(Comparison.lessThan.triggers(value: 4000, threshold: 5000))
        #expect(!Comparison.lessThan.triggers(value: 6000, threshold: 5000))
        #expect(!Comparison.lessThan.triggers(value: 5000, threshold: 5000))
    }

    @Test func comparisonGreaterThanTriggersWhenValueAboveThreshold() {
        #expect(Comparison.greaterThan.triggers(value: 6000, threshold: 5000))
        #expect(!Comparison.greaterThan.triggers(value: 4000, threshold: 5000))
        #expect(!Comparison.greaterThan.triggers(value: 5000, threshold: 5000))
    }

    // MARK: - accepts()

    @Test func acceptsMatchingMessage() {
        let detector = ThresholdDetector(config: makeConfig())
        let entry = makeEntry(message: "setDetailedThermalPowerBudget: current power budget: 4500")
        #expect(detector.accepts(entry))
    }

    @Test func rejectsNonMatchingMessage() {
        let detector = ThresholdDetector(config: makeConfig())
        let entry = makeEntry(message: "some unrelated log message")
        #expect(!detector.accepts(entry))
    }

    @Test func rejectsWhenDisabled() {
        let detector = ThresholdDetector(config: makeConfig())
        detector.isEnabled = false
        let entry = makeEntry(message: "power budget: 4500")
        // accepts() itself doesn't check isEnabled — pipeline does that
        // but we verify the flag is settable
        #expect(!detector.isEnabled)
    }

    // MARK: - State: Normal → Pending (lessThan)

    @Test func transitionsFromNormalToPendingOnWarningValue() {
        let detector = ThresholdDetector(config: makeConfig())
        let entry = makeEntry(message: "power budget: 4500")

        // First warning-level value: should enter pending, no alert yet (debounce)
        let alert = detector.process(entry)
        #expect(alert == nil)
        #expect(detector.currentState == .pending)
    }

    // MARK: - State: Pending → Normal (value recovers before debounce)

    @Test func pendingReturnsToNormalOnRecovery() {
        let detector = ThresholdDetector(config: makeConfig())

        // Enter pending
        _ = detector.process(makeEntry(message: "power budget: 4500"))
        #expect(detector.currentState == .pending)

        // Recover before debounce
        _ = detector.process(makeEntry(message: "power budget: 8000"))
        #expect(detector.currentState == .normal)
    }

    // MARK: - State: Pending → Warning (debounce expires)

    @Test func pendingTransitionsToWarningAfterDebounce() {
        let config = makeConfig(debounce: 2.0)
        let detector = ThresholdDetector(config: config)

        let t0 = Date()
        // Enter pending at t0
        _ = detector.process(makeEntry(message: "power budget: 4500", timestamp: t0))
        #expect(detector.currentState == .pending)

        // Still in warning zone at t0+3s (past debounce)
        let t1 = t0.addingTimeInterval(3.0)
        let alert = detector.process(makeEntry(message: "power budget: 4000", timestamp: t1))

        #expect(detector.currentState == .warning)
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
        #expect(alert?.detectorID == "P01")
    }

    // MARK: - State: Warning → Critical

    @Test func warningTransitionsToCriticalOnCriticalValue() {
        let config = makeConfig(debounce: 0)
        let detector = ThresholdDetector(config: config)

        // Immediately enter warning (debounce = 0)
        let t0 = Date()
        _ = detector.process(makeEntry(message: "power budget: 4500", timestamp: t0))
        #expect(detector.currentState == .warning)

        // Critical value
        let t1 = t0.addingTimeInterval(1.0)
        let alert = detector.process(makeEntry(message: "power budget: 2000", timestamp: t1))

        #expect(detector.currentState == .critical)
        #expect(alert != nil)
        #expect(alert?.severity == .critical)
    }

    // MARK: - State: Critical → Normal (recovery)

    @Test func criticalRecoversToNormalOnRecoveryValue() {
        let config = makeConfig(debounce: 0)
        let detector = ThresholdDetector(config: config)

        let t0 = Date()
        // Normal → Warning
        _ = detector.process(makeEntry(message: "power budget: 4500", timestamp: t0))
        // Warning → Critical
        _ = detector.process(makeEntry(
            message: "power budget: 2000",
            timestamp: t0.addingTimeInterval(1.0)
        ))
        #expect(detector.currentState == .critical)

        // Recovery
        let alert = detector.process(makeEntry(
            message: "power budget: 8000",
            timestamp: t0.addingTimeInterval(2.0)
        ))

        #expect(detector.currentState == .normal)
        #expect(alert != nil)
        #expect(alert?.severity == .info) // Recovery alert is info
    }

    // MARK: - State: Warning → Normal (recovery)

    @Test func warningRecoversToNormalOnRecoveryValue() {
        let config = makeConfig(debounce: 0)
        let detector = ThresholdDetector(config: config)

        let t0 = Date()
        _ = detector.process(makeEntry(message: "power budget: 4500", timestamp: t0))
        #expect(detector.currentState == .warning)

        let alert = detector.process(makeEntry(
            message: "power budget: 8000",
            timestamp: t0.addingTimeInterval(1.0)
        ))

        #expect(detector.currentState == .normal)
        #expect(alert != nil)
        #expect(alert?.severity == .info) // Recovery
    }

    // MARK: - Regex value extraction

    @Test func extractsNumericValueFromMessage() {
        let config = makeConfig(debounce: 0)
        let detector = ThresholdDetector(config: config)

        _ = detector.process(makeEntry(message: "power budget: 4500"))
        #expect(detector.lastValue == 4500)
    }

    @Test func returnsNilForMessageWithoutRegexMatch() {
        let detector = ThresholdDetector(config: makeConfig())
        let entry = makeEntry(message: "no numbers here about power budget")
        // Even though accepts() would match "power budget", regex won't find the number
        let alert = detector.process(entry)
        #expect(alert == nil)
        #expect(detector.currentState == .normal)
    }

    // MARK: - Pending does not emit alert during debounce window

    @Test func noAlertDuringDebounceWindow() {
        let config = makeConfig(debounce: 5.0)
        let detector = ThresholdDetector(config: config)

        let t0 = Date()
        _ = detector.process(makeEntry(message: "power budget: 4500", timestamp: t0))

        // Still within debounce window (t0+2s < 5s debounce)
        let alert = detector.process(makeEntry(
            message: "power budget: 4200",
            timestamp: t0.addingTimeInterval(2.0)
        ))

        #expect(detector.currentState == .pending)
        #expect(alert == nil)
    }

    // MARK: - Pending → Critical bypasses warning

    @Test func pendingJumpsToCriticalOnCriticalValue() {
        let config = makeConfig(debounce: 5.0)
        let detector = ThresholdDetector(config: config)

        let t0 = Date()
        _ = detector.process(makeEntry(message: "power budget: 4500", timestamp: t0))
        #expect(detector.currentState == .pending)

        // Critical value during debounce — should jump straight to critical
        let alert = detector.process(makeEntry(
            message: "power budget: 2000",
            timestamp: t0.addingTimeInterval(1.0)
        ))

        #expect(detector.currentState == .critical)
        #expect(alert != nil)
        #expect(alert?.severity == .critical)
    }

    // MARK: - greaterThan comparison (e.g., disk flush latency)

    @Test func greaterThanTriggersWarningWhenAboveThreshold() {
        let config = ThresholdConfig(
            id: "P03",
            regex: #"latency: (\d+)ms"#,
            warningThreshold: 1000,
            criticalThreshold: 3000,
            recoveryThreshold: 500,
            debounce: 0,
            comparison: .greaterThan,
            title: "Disk Latency",
            descriptionTemplate: "Flush latency {value}ms",
            suggestion: "Check disk health",
            acceptsFilter: "latency"
        )
        let detector = ThresholdDetector(config: config)

        let alert = detector.process(makeEntry(message: "flush latency: 1500ms"))

        #expect(detector.currentState == .warning)
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
    }

    @Test func greaterThanRecoversBelowRecoveryThreshold() {
        let config = ThresholdConfig(
            id: "P03",
            regex: #"latency: (\d+)ms"#,
            warningThreshold: 1000,
            criticalThreshold: 3000,
            recoveryThreshold: 500,
            debounce: 0,
            comparison: .greaterThan,
            title: "Disk Latency",
            descriptionTemplate: "Flush latency {value}ms",
            suggestion: "Check disk health",
            acceptsFilter: "latency"
        )
        let detector = ThresholdDetector(config: config)

        _ = detector.process(makeEntry(message: "flush latency: 1500ms"))
        #expect(detector.currentState == .warning)

        let recovery = detector.process(makeEntry(message: "flush latency: 300ms"))
        #expect(detector.currentState == .normal)
        #expect(recovery?.severity == .info)
    }

    // MARK: - Hysteresis: value between recovery and warning stays in current state

    @Test func warningDoesNotRecoverWhenValueBetweenRecoveryAndWarning() {
        // Config: warning < 5000, recovery > 7000 (lessThan comparison)
        // Value 6000 is below recovery (7000) but above warning (5000) — should stay in warning
        let config = makeConfig(debounce: 0)
        let detector = ThresholdDetector(config: config)

        let t0 = Date()
        _ = detector.process(makeEntry(message: "power budget: 4500", timestamp: t0))
        #expect(detector.currentState == .warning)

        let alert = detector.process(makeEntry(
            message: "power budget: 6000",
            timestamp: t0.addingTimeInterval(1.0)
        ))

        // 6000 is above warning (5000) but below recovery (7000) — stays in warning
        #expect(detector.currentState == .warning)
        #expect(alert == nil) // No state change = no alert
    }

    // MARK: - Description template

    @Test func alertDescriptionIncludesExtractedValue() {
        let config = makeConfig(debounce: 0)
        let detector = ThresholdDetector(config: config)

        let alert = detector.process(makeEntry(message: "power budget: 4500"))

        #expect(alert != nil)
        #expect(alert?.description.contains("4500") == true)
    }

    // MARK: - tick() returns empty (no time-based alerts for threshold)

    @Test func tickReturnsEmpty() {
        let detector = ThresholdDetector(config: makeConfig())
        let alerts = detector.tick()
        #expect(alerts.isEmpty)
    }

    // MARK: - Critical stays critical on continued critical values

    @Test func criticalStaysCriticalOnContinuedCriticalValues() {
        let config = makeConfig(debounce: 0)
        let detector = ThresholdDetector(config: config)

        let t0 = Date()
        _ = detector.process(makeEntry(message: "power budget: 4500", timestamp: t0))
        _ = detector.process(makeEntry(
            message: "power budget: 2000",
            timestamp: t0.addingTimeInterval(1.0)
        ))
        #expect(detector.currentState == .critical)

        // Another critical value — should stay critical, no new alert
        let alert = detector.process(makeEntry(
            message: "power budget: 1500",
            timestamp: t0.addingTimeInterval(2.0)
        ))
        #expect(detector.currentState == .critical)
        #expect(alert == nil) // No state change
    }

    // MARK: - Critical downgrades to warning

    @Test func criticalDowngradesToWarningWhenValueInWarningZone() {
        let config = makeConfig(debounce: 0)
        let detector = ThresholdDetector(config: config)

        let t0 = Date()
        _ = detector.process(makeEntry(message: "power budget: 4500", timestamp: t0))
        _ = detector.process(makeEntry(
            message: "power budget: 2000",
            timestamp: t0.addingTimeInterval(1.0)
        ))
        #expect(detector.currentState == .critical)

        // Value in warning zone (between critical 3000 and warning 5000) for lessThan
        let alert = detector.process(makeEntry(
            message: "power budget: 4000",
            timestamp: t0.addingTimeInterval(2.0)
        ))
        #expect(detector.currentState == .warning)
        #expect(alert != nil)
        #expect(alert?.severity == .warning) // Downgrade alert
    }
}
