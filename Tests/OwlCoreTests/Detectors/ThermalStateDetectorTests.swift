import Foundation
import Testing
@testable import OwlCore

@Suite("ThermalStateDetector")
struct ThermalStateDetectorTests {

    // MARK: - Helpers

    private func makeDetector(
        thermalState: @escaping @Sendable () -> ProcessInfo.ThermalState
    ) -> ThermalStateDetector {
        ThermalStateDetector(
            id: "test_thermal_state",
            thermalStateProvider: thermalState
        )
    }

    private func makeMetrics(cpu: Double = 50) -> SystemMetrics {
        SystemMetrics(cpuUsage: cpu, memoryTotal: 16_000_000_000, memoryUsed: 8_000_000_000)
    }

    // MARK: - Nominal state

    @Test("no alert when thermal state stays nominal")
    func nominalNoAlert() {
        let detector = makeDetector(thermalState: { .nominal })
        let alert = detector.process(makeMetrics())
        #expect(alert == nil)
    }

    // MARK: - Transitions to warning

    @Test("fair thermal state triggers warning")
    func fairWarning() {
        nonisolated(unsafe) var state: ProcessInfo.ThermalState = .nominal
        let provider: @Sendable () -> ProcessInfo.ThermalState = { state }
        let detector = makeDetector(thermalState: provider)

        // First call establishes baseline
        _ = detector.process(makeMetrics())

        // Transition to fair
        state = .fair
        let alert = detector.process(makeMetrics())
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
        #expect(alert?.detectorID == "test_thermal_state")
    }

    @Test("serious thermal state triggers warning")
    func seriousWarning() {
        nonisolated(unsafe) var state: ProcessInfo.ThermalState = .nominal
        let provider: @Sendable () -> ProcessInfo.ThermalState = { state }
        let detector = makeDetector(thermalState: provider)

        _ = detector.process(makeMetrics())

        state = .serious
        let alert = detector.process(makeMetrics())
        #expect(alert != nil)
        #expect(alert?.severity == .warning)
    }

    // MARK: - Critical

    @Test("critical thermal state triggers critical alert")
    func criticalAlert() {
        nonisolated(unsafe) var state: ProcessInfo.ThermalState = .nominal
        let provider: @Sendable () -> ProcessInfo.ThermalState = { state }
        let detector = makeDetector(thermalState: provider)

        _ = detector.process(makeMetrics())

        state = .critical
        let alert = detector.process(makeMetrics())
        #expect(alert != nil)
        #expect(alert?.severity == .critical)
    }

    // MARK: - Recovery

    @Test("recovery to nominal emits info alert")
    func recoveryToNominal() {
        nonisolated(unsafe) var state: ProcessInfo.ThermalState = .nominal
        let provider: @Sendable () -> ProcessInfo.ThermalState = { state }
        let detector = makeDetector(thermalState: provider)

        _ = detector.process(makeMetrics())

        // Go to fair
        state = .fair
        _ = detector.process(makeMetrics())

        // Recover
        state = .nominal
        let alert = detector.process(makeMetrics())
        #expect(alert != nil)
        #expect(alert?.severity == .info) // recovery
    }

    // MARK: - Same state no re-emit

    @Test("same state does not re-emit alert")
    func sameStateNoReemit() {
        nonisolated(unsafe) var state: ProcessInfo.ThermalState = .nominal
        let provider: @Sendable () -> ProcessInfo.ThermalState = { state }
        let detector = makeDetector(thermalState: provider)

        _ = detector.process(makeMetrics())

        state = .fair
        let alert1 = detector.process(makeMetrics())
        #expect(alert1 != nil)

        // Same state again
        let alert2 = detector.process(makeMetrics())
        #expect(alert2 == nil)
    }

    // MARK: - Escalation

    @Test("escalation from fair to critical emits critical alert")
    func escalation() {
        nonisolated(unsafe) var state: ProcessInfo.ThermalState = .nominal
        let provider: @Sendable () -> ProcessInfo.ThermalState = { state }
        let detector = makeDetector(thermalState: provider)

        _ = detector.process(makeMetrics())

        state = .fair
        let alert1 = detector.process(makeMetrics())
        #expect(alert1?.severity == .warning)

        state = .critical
        let alert2 = detector.process(makeMetrics())
        #expect(alert2?.severity == .critical)
    }

    // MARK: - Disabled

    @Test("disabled detector produces no alerts")
    func disabledNoAlert() {
        nonisolated(unsafe) var state: ProcessInfo.ThermalState = .nominal
        let provider: @Sendable () -> ProcessInfo.ThermalState = { state }
        let detector = makeDetector(thermalState: provider)
        detector.isEnabled = false

        _ = detector.process(makeMetrics())

        state = .critical
        let alert = detector.process(makeMetrics())
        #expect(alert == nil)
    }

    // MARK: - Tick

    @Test("tick returns empty (no time-based logic)")
    func tickReturnsEmpty() {
        let detector = makeDetector(thermalState: { .nominal })
        let alerts = detector.tick(at: Date())
        #expect(alerts.isEmpty)
    }
}
