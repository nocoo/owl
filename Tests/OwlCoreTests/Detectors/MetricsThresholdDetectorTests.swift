import Foundation
import Testing
@testable import OwlCore

@Suite("MetricsThresholdDetector")
struct MetricsThresholdDetectorTests {

    // MARK: - Helpers

    private func makeConfig(
        warningThreshold: Double = 85,
        criticalThreshold: Double = 95,
        recoveryThreshold: Double = 80,
        sustainedDuration: TimeInterval = 30
    ) -> MetricsThresholdConfig {
        MetricsThresholdConfig(
            id: "test_threshold",
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold,
            recoveryThreshold: recoveryThreshold,
            sustainedDuration: sustainedDuration,
            titleKey: .alertMemoryPressureTitle,
            descriptionKey: { .alertMemoryPressureDesc($0) },
            suggestionKey: .alertMemoryPressureSuggestion,
            formatValue: { String(format: "%.0f", $0) }
        )
    }

    private func makeDetector(
        warningThreshold: Double = 85,
        criticalThreshold: Double = 95,
        recoveryThreshold: Double = 80,
        sustainedDuration: TimeInterval = 30,
        extractor: @escaping @Sendable (SystemMetrics) -> Double = { $0.memoryPressure }
    ) -> MetricsThresholdDetector {
        MetricsThresholdDetector(
            config: makeConfig(
                warningThreshold: warningThreshold,
                criticalThreshold: criticalThreshold,
                recoveryThreshold: recoveryThreshold,
                sustainedDuration: sustainedDuration
            ),
            extractor: extractor
        )
    }

    private func makeMetrics(
        memoryUsed: UInt64 = 8_000_000_000,
        memoryTotal: UInt64 = 16_000_000_000
    ) -> SystemMetrics {
        SystemMetrics(
            cpuUsage: 10,
            memoryTotal: memoryTotal,
            memoryUsed: memoryUsed
        )
    }

    /// Create metrics with a specific memory pressure percentage.
    private func metricsWithPressure(_ percent: Double) -> SystemMetrics {
        let total: UInt64 = 16_000_000_000
        let used = UInt64(Double(total) * percent / 100.0)
        return SystemMetrics(
            cpuUsage: 10,
            memoryTotal: total,
            memoryUsed: used
        )
    }

    // MARK: - Normal state

    @Test("no alert when value is below threshold")
    func normalNoAlert() {
        let detector = makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        _ = detector.process(metricsWithPressure(50))
        let alerts = detector.tick(at: t0)
        #expect(alerts.isEmpty)
        #expect(detector.currentState == .normal)
    }

    @Test("no alert at exactly warning threshold (not above)")
    func exactThresholdNoTrigger() {
        let detector = makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        _ = detector.process(metricsWithPressure(85))
        let alerts = detector.tick(at: t0)
        #expect(alerts.isEmpty)
        #expect(detector.currentState == .normal)
    }

    // MARK: - Elevated state tracking

    @Test("transitions to elevated when value exceeds warning threshold")
    func elevatedTransition() {
        let detector = makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        _ = detector.process(metricsWithPressure(90))
        let alerts = detector.tick(at: t0)
        #expect(alerts.isEmpty)
        if case .elevated = detector.currentState {
            // expected
        } else {
            Issue.record("Expected .elevated state, got \(detector.currentState)")
        }
    }

    @Test("returns to normal when value drops during elevated")
    func elevatedRecovery() {
        let detector = makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        // Go elevated
        _ = detector.process(metricsWithPressure(90))
        _ = detector.tick(at: t0)

        // Value drops below recovery threshold
        _ = detector.process(metricsWithPressure(75))
        let t1 = Date(timeIntervalSince1970: 1015)
        let alerts = detector.tick(at: t1)
        #expect(alerts.isEmpty) // no recovery alert from elevated
        #expect(detector.currentState == .normal)
    }

    // MARK: - Warning after duration

    @Test("emits warning after sustained value above threshold for configured duration")
    func warningAfterDuration() {
        let detector = makeDetector(sustainedDuration: 30)
        let t0 = Date(timeIntervalSince1970: 1000)

        // Enter elevated
        _ = detector.process(metricsWithPressure(90))
        _ = detector.tick(at: t0)

        // Not enough time yet
        let t1 = Date(timeIntervalSince1970: 1020)
        _ = detector.process(metricsWithPressure(91))
        let alerts1 = detector.tick(at: t1)
        #expect(alerts1.isEmpty)

        // Duration met
        let t2 = Date(timeIntervalSince1970: 1030)
        _ = detector.process(metricsWithPressure(92))
        let alerts2 = detector.tick(at: t2)
        #expect(alerts2.count == 1)
        #expect(alerts2[0].severity == .warning)
        #expect(alerts2[0].detectorID == "test_threshold")
        if case .warning = detector.currentState {
            // expected
        } else {
            Issue.record("Expected .warning state, got \(detector.currentState)")
        }
    }

    // MARK: - Recovery from warning

    @Test("emits recovery alert when value drops below recovery threshold from warning")
    func recoveryFromWarning() {
        let detector = makeDetector(sustainedDuration: 10)
        let t0 = Date(timeIntervalSince1970: 1000)

        // Enter elevated then warning
        _ = detector.process(metricsWithPressure(90))
        _ = detector.tick(at: t0)
        let t1 = Date(timeIntervalSince1970: 1010)
        _ = detector.process(metricsWithPressure(90))
        let warningAlerts = detector.tick(at: t1)
        #expect(warningAlerts.count == 1)

        // Value drops below recovery
        _ = detector.process(metricsWithPressure(75))
        let t2 = Date(timeIntervalSince1970: 1015)
        let recoveryAlerts = detector.tick(at: t2)
        #expect(recoveryAlerts.count == 1)
        #expect(recoveryAlerts[0].severity == .info)
        #expect(detector.currentState == .normal)
    }

    // MARK: - Critical escalation

    @Test("escalates to critical when value exceeds critical threshold")
    func criticalEscalation() {
        let detector = makeDetector(sustainedDuration: 10)
        let t0 = Date(timeIntervalSince1970: 1000)

        // Enter warning
        _ = detector.process(metricsWithPressure(90))
        _ = detector.tick(at: t0)
        let t1 = Date(timeIntervalSince1970: 1010)
        _ = detector.process(metricsWithPressure(90))
        let warningAlerts = detector.tick(at: t1)
        #expect(warningAlerts.count == 1)
        #expect(warningAlerts[0].severity == .warning)

        // Value exceeds critical threshold
        _ = detector.process(metricsWithPressure(96))
        let t2 = Date(timeIntervalSince1970: 1015)
        let criticalAlerts = detector.tick(at: t2)
        #expect(criticalAlerts.count == 1)
        #expect(criticalAlerts[0].severity == .critical)
        if case .critical = detector.currentState {
            // expected
        } else {
            Issue.record("Expected .critical state, got \(detector.currentState)")
        }
    }

    @Test("recovery from critical state")
    func recoveryFromCritical() {
        let detector = makeDetector(sustainedDuration: 10)
        let t0 = Date(timeIntervalSince1970: 1000)

        // Enter warning → critical
        _ = detector.process(metricsWithPressure(90))
        _ = detector.tick(at: t0)
        _ = detector.process(metricsWithPressure(90))
        _ = detector.tick(at: Date(timeIntervalSince1970: 1010))

        _ = detector.process(metricsWithPressure(96))
        _ = detector.tick(at: Date(timeIntervalSince1970: 1015))

        // Value drops below recovery
        _ = detector.process(metricsWithPressure(75))
        let alerts = detector.tick(at: Date(timeIntervalSince1970: 1020))
        #expect(alerts.count == 1)
        #expect(alerts[0].severity == .info)
        #expect(detector.currentState == .normal)
    }

    // MARK: - Hysteresis

    @Test("does not recover when value is between recovery and warning thresholds")
    func hysteresis() {
        let detector = makeDetector(
            warningThreshold: 85,
            recoveryThreshold: 80,
            sustainedDuration: 10
        )
        let t0 = Date(timeIntervalSince1970: 1000)

        // Enter warning
        _ = detector.process(metricsWithPressure(90))
        _ = detector.tick(at: t0)
        _ = detector.process(metricsWithPressure(90))
        _ = detector.tick(at: Date(timeIntervalSince1970: 1010))

        // Value drops to 82% — above recovery (80%), below warning (85%)
        // Should NOT recover — hysteresis zone
        _ = detector.process(metricsWithPressure(82))
        let alerts = detector.tick(at: Date(timeIntervalSince1970: 1015))
        #expect(alerts.isEmpty)
        if case .warning = detector.currentState {
            // expected — stays in warning
        } else {
            Issue.record("Expected .warning state (hysteresis), got \(detector.currentState)")
        }
    }

    // MARK: - Direct to critical from elevated

    @Test("jumps directly to critical when value exceeds critical threshold during sustained period")
    func directToCriticalFromElevated() {
        let detector = makeDetector(sustainedDuration: 10)
        let t0 = Date(timeIntervalSince1970: 1000)

        // Enter elevated with value above critical
        _ = detector.process(metricsWithPressure(97))
        _ = detector.tick(at: t0)

        // Duration met while above critical — should go straight to critical
        let t1 = Date(timeIntervalSince1970: 1010)
        _ = detector.process(metricsWithPressure(97))
        let alerts = detector.tick(at: t1)
        #expect(alerts.count == 1)
        #expect(alerts[0].severity == .critical)
        if case .critical = detector.currentState {
            // expected
        } else {
            Issue.record("Expected .critical state, got \(detector.currentState)")
        }
    }

    // MARK: - Short spike

    @Test("short spike that recovers before duration does not trigger warning")
    func shortSpikeNoTrigger() {
        let detector = makeDetector(sustainedDuration: 30)
        let t0 = Date(timeIntervalSince1970: 1000)

        // Spike high
        _ = detector.process(metricsWithPressure(92))
        _ = detector.tick(at: t0)

        // Drop after 15s (before 30s duration)
        _ = detector.process(metricsWithPressure(70))
        let t1 = Date(timeIntervalSince1970: 1015)
        let alerts = detector.tick(at: t1)
        #expect(alerts.isEmpty)
        #expect(detector.currentState == .normal)
    }

    // MARK: - Disabled detector

    @Test("disabled detector produces no alerts")
    func disabledNoAlert() {
        let detector = makeDetector(sustainedDuration: 10)
        detector.isEnabled = false
        let t0 = Date(timeIntervalSince1970: 1000)

        _ = detector.process(metricsWithPressure(95))
        let alerts = detector.tick(at: t0)
        #expect(alerts.isEmpty)
    }

    // MARK: - Custom extractor

    @Test("works with custom extractor (disk usage)")
    func customExtractor() {
        let detector = MetricsThresholdDetector(
            config: makeConfig(sustainedDuration: 10),
            extractor: { $0.disk.usedPercent }
        )
        let t0 = Date(timeIntervalSince1970: 1000)

        let metrics = SystemMetrics(
            cpuUsage: 10,
            memoryTotal: 16_000_000_000,
            memoryUsed: 8_000_000_000,
            disk: DiskMetrics(
                totalBytes: 500_000_000_000,
                usedBytes: 460_000_000_000, // 92%
                readBytesPerSec: 0,
                writeBytesPerSec: 0
            )
        )

        _ = detector.process(metrics)
        _ = detector.tick(at: t0)

        // Duration met
        _ = detector.process(metrics)
        let t1 = Date(timeIntervalSince1970: 1010)
        let alerts = detector.tick(at: t1)
        #expect(alerts.count == 1)
        #expect(alerts[0].severity == .warning)
    }
}
