import Foundation
import Testing
@testable import OwlCore

@Suite("MemoryPressurePattern")
struct MemoryPressurePatternTests {

    @Test("has correct ID")
    func correctID() {
        #expect(MemoryPressurePattern.id == "memory_pressure")
    }

    @Test("creates detector with correct ID")
    func detectorID() {
        let detector = MemoryPressurePattern.makeDetector()
        #expect(detector.id == "memory_pressure")
    }

    @Test("detector starts in normal state")
    func initialState() {
        let detector = MemoryPressurePattern.makeDetector()
        #expect(detector.currentState == .normal)
    }

    @Test("extracts memory pressure correctly")
    func extractsMemoryPressure() {
        let detector = MemoryPressurePattern.makeDetector()
        let total: UInt64 = 16_000_000_000
        let used = UInt64(Double(total) * 0.90) // 90%
        let metrics = SystemMetrics(
            cpuUsage: 10,
            memoryTotal: total,
            memoryUsed: used
        )

        _ = detector.process(metrics)
        let t0 = Date(timeIntervalSince1970: 1000)
        _ = detector.tick(at: t0)

        // Should be in elevated state (90% > 85% warning threshold)
        if case .elevated = detector.currentState {
            // expected
        } else {
            Issue.record("Expected .elevated, got \(detector.currentState)")
        }
    }
}
