import Foundation
import Testing
@testable import OwlCore

@Suite("SustainedCPUDetector")
struct SustainedCPUDetectorTests {

    // MARK: - Helpers

    private func makeDetector(
        threshold: Double = 80,
        duration: TimeInterval = 60,
        thermalState: @escaping @Sendable () -> ProcessInfo.ThermalState = { .nominal }
    ) -> SustainedCPUDetector {
        SustainedCPUDetector(
            config: SustainedCPUConfig(
                id: "test_cpu",
                threshold: threshold,
                duration: duration
            ),
            thermalStateProvider: thermalState
        )
    }

    private func makeMetrics(cpu: Double) -> SystemMetrics {
        SystemMetrics(cpuUsage: cpu, memoryTotal: 16_000_000_000, memoryUsed: 8_000_000_000)
    }

    // MARK: - Normal state

    @Test("no alert when CPU is below threshold")
    func normalNoAlert() {
        let detector = makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        _ = detector.process(makeMetrics(cpu: 50))
        let alerts = detector.tick(at: t0)
        #expect(alerts.isEmpty)
        #expect(detector.currentState == .normal)
    }

    @Test("no alert at exactly threshold (not above)")
    func exactThresholdNoTrigger() {
        let detector = makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        _ = detector.process(makeMetrics(cpu: 80))
        let alerts = detector.tick(at: t0)
        #expect(alerts.isEmpty)
        #expect(detector.currentState == .normal)
    }

    // MARK: - Elevated state tracking

    @Test("transitions to elevated when CPU exceeds threshold")
    func elevatedTransition() {
        let detector = makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        _ = detector.process(makeMetrics(cpu: 90))
        let alerts = detector.tick(at: t0)
        #expect(alerts.isEmpty)
        if case .elevated = detector.currentState {
            // expected
        } else {
            Issue.record("Expected .elevated state, got \(detector.currentState)")
        }
    }

    @Test("returns to normal when CPU drops during elevated")
    func elevatedRecovery() {
        let detector = makeDetector()
        let t0 = Date(timeIntervalSince1970: 1000)

        // Go elevated
        _ = detector.process(makeMetrics(cpu: 90))
        _ = detector.tick(at: t0)

        // CPU drops
        _ = detector.process(makeMetrics(cpu: 50))
        let t1 = Date(timeIntervalSince1970: 1030)
        let alerts = detector.tick(at: t1)
        #expect(alerts.isEmpty) // no recovery alert from elevated (no warning was emitted)
        #expect(detector.currentState == .normal)
    }

    // MARK: - Warning after duration

    @Test("emits warning after sustained high CPU for configured duration")
    func warningAfterDuration() {
        let detector = makeDetector(duration: 60)
        let t0 = Date(timeIntervalSince1970: 1000)

        // Enter elevated
        _ = detector.process(makeMetrics(cpu: 90))
        _ = detector.tick(at: t0)

        // Not enough time yet
        let t1 = Date(timeIntervalSince1970: 1050)
        _ = detector.process(makeMetrics(cpu: 92))
        let alerts1 = detector.tick(at: t1)
        #expect(alerts1.isEmpty)

        // Duration met
        let t2 = Date(timeIntervalSince1970: 1060)
        _ = detector.process(makeMetrics(cpu: 91))
        let alerts2 = detector.tick(at: t2)
        #expect(alerts2.count == 1)
        #expect(alerts2[0].severity == .warning)
        #expect(alerts2[0].detectorID == "test_cpu")
        if case .warning = detector.currentState {
            // expected
        } else {
            Issue.record("Expected .warning state, got \(detector.currentState)")
        }
    }

    // MARK: - Recovery from warning

    @Test("emits recovery alert when CPU drops from warning state")
    func recoveryFromWarning() {
        let detector = makeDetector(duration: 10)
        let t0 = Date(timeIntervalSince1970: 1000)

        // Enter elevated then warning
        _ = detector.process(makeMetrics(cpu: 90))
        _ = detector.tick(at: t0)
        let t1 = Date(timeIntervalSince1970: 1010)
        _ = detector.process(makeMetrics(cpu: 90))
        let warningAlerts = detector.tick(at: t1)
        #expect(warningAlerts.count == 1)

        // CPU drops
        _ = detector.process(makeMetrics(cpu: 50))
        let t2 = Date(timeIntervalSince1970: 1015)
        let recoveryAlerts = detector.tick(at: t2)
        #expect(recoveryAlerts.count == 1)
        #expect(recoveryAlerts[0].severity == .info) // recovery
        #expect(detector.currentState == .normal)
    }

    // MARK: - Critical escalation with thermal state

    @Test("escalates to critical when thermal state is critical during warning")
    func criticalEscalation() {
        nonisolated(unsafe) var thermal: ProcessInfo.ThermalState = .nominal
        let thermalProvider: @Sendable () -> ProcessInfo.ThermalState = { thermal }
        let detector = makeDetector(duration: 10, thermalState: thermalProvider)
        let t0 = Date(timeIntervalSince1970: 1000)

        // Enter warning
        _ = detector.process(makeMetrics(cpu: 90))
        _ = detector.tick(at: t0)
        let t1 = Date(timeIntervalSince1970: 1010)
        _ = detector.process(makeMetrics(cpu: 90))
        let warningAlerts = detector.tick(at: t1)
        #expect(warningAlerts.count == 1)
        #expect(warningAlerts[0].severity == .warning)

        // Thermal becomes critical
        thermal = .critical
        let t2 = Date(timeIntervalSince1970: 1015)
        _ = detector.process(makeMetrics(cpu: 95))
        let criticalAlerts = detector.tick(at: t2)
        #expect(criticalAlerts.count == 1)
        #expect(criticalAlerts[0].severity == .critical)
        if case .critical = detector.currentState {
            // expected
        } else {
            Issue.record("Expected .critical state, got \(detector.currentState)")
        }
    }

    @Test("downgrades from critical to warning when thermal recovers")
    func criticalDowngrade() {
        nonisolated(unsafe) var thermal: ProcessInfo.ThermalState = .nominal
        let thermalProvider: @Sendable () -> ProcessInfo.ThermalState = { thermal }
        let detector = makeDetector(duration: 10, thermalState: thermalProvider)
        let t0 = Date(timeIntervalSince1970: 1000)

        // Enter warning → critical
        _ = detector.process(makeMetrics(cpu: 90))
        _ = detector.tick(at: t0)
        _ = detector.process(makeMetrics(cpu: 90))
        _ = detector.tick(at: Date(timeIntervalSince1970: 1010))

        thermal = .critical
        _ = detector.process(makeMetrics(cpu: 95))
        _ = detector.tick(at: Date(timeIntervalSince1970: 1015))

        // Thermal recovers, but CPU still high → downgrade to warning
        thermal = .nominal
        _ = detector.process(makeMetrics(cpu: 90))
        let alerts = detector.tick(at: Date(timeIntervalSince1970: 1020))
        #expect(alerts.count == 1)
        #expect(alerts[0].severity == .warning)
        if case .warning = detector.currentState {
            // expected
        } else {
            Issue.record("Expected .warning state, got \(detector.currentState)")
        }
    }

    // MARK: - Short spikes don't trigger

    @Test("short CPU spike that recovers before duration does not trigger warning")
    func shortSpikeNoTrigger() {
        let detector = makeDetector(duration: 60)
        let t0 = Date(timeIntervalSince1970: 1000)

        // Spike high
        _ = detector.process(makeMetrics(cpu: 95))
        _ = detector.tick(at: t0)

        // Drop after 30s (before 60s duration)
        _ = detector.process(makeMetrics(cpu: 40))
        let t1 = Date(timeIntervalSince1970: 1030)
        let alerts = detector.tick(at: t1)
        #expect(alerts.isEmpty)
        #expect(detector.currentState == .normal)

        // Spike again — should start fresh elevated tracking
        _ = detector.process(makeMetrics(cpu: 90))
        let t2 = Date(timeIntervalSince1970: 1035)
        _ = detector.tick(at: t2)
        if case .elevated = detector.currentState {
            // expected — fresh tracking, not carried over
        } else {
            Issue.record("Expected .elevated state, got \(detector.currentState)")
        }
    }

    // MARK: - Disabled detector

    @Test("disabled detector produces no alerts")
    func disabledNoAlert() {
        let detector = makeDetector(duration: 10)
        detector.isEnabled = false
        let t0 = Date(timeIntervalSince1970: 1000)

        _ = detector.process(makeMetrics(cpu: 95))
        let alerts = detector.tick(at: t0)
        #expect(alerts.isEmpty)
    }

    // MARK: - Recovery from critical

    @Test("emits recovery alert when CPU drops from critical state")
    func recoveryFromCritical() {
        nonisolated(unsafe) var thermal: ProcessInfo.ThermalState = .nominal
        let thermalProvider: @Sendable () -> ProcessInfo.ThermalState = { thermal }
        let detector = makeDetector(duration: 10, thermalState: thermalProvider)
        let t0 = Date(timeIntervalSince1970: 1000)

        // Enter warning → critical
        _ = detector.process(makeMetrics(cpu: 90))
        _ = detector.tick(at: t0)
        _ = detector.process(makeMetrics(cpu: 90))
        _ = detector.tick(at: Date(timeIntervalSince1970: 1010))

        thermal = .critical
        _ = detector.process(makeMetrics(cpu: 95))
        _ = detector.tick(at: Date(timeIntervalSince1970: 1015))

        // CPU drops from critical
        _ = detector.process(makeMetrics(cpu: 40))
        let alerts = detector.tick(at: Date(timeIntervalSince1970: 1020))
        #expect(alerts.count == 1)
        #expect(alerts[0].severity == .info) // recovery
        #expect(detector.currentState == .normal)
    }
}
