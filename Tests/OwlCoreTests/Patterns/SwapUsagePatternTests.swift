import Foundation
import Testing
@testable import OwlCore

@Suite("SwapUsagePattern")
struct SwapUsagePatternTests {

    @Test("has correct ID")
    func correctID() {
        #expect(SwapUsagePattern.id == "swap_usage")
    }

    @Test("creates detector with correct ID")
    func detectorID() {
        let detector = SwapUsagePattern.makeDetector()
        #expect(detector.id == "swap_usage")
    }

    @Test("detector starts in normal state")
    func initialState() {
        let detector = SwapUsagePattern.makeDetector()
        #expect(detector.currentState == .normal)
    }

    @Test("extracts swap usage correctly")
    func extractsSwapUsage() {
        let detector = SwapUsagePattern.makeDetector()
        let gb: UInt64 = 1_073_741_824
        let metrics = SystemMetrics(
            cpuUsage: 10,
            memoryTotal: 16 * gb,
            memoryUsed: 8 * gb,
            extendedMemory: ExtendedMemoryInfo(
                total: 16 * gb,
                used: 8 * gb,
                swapTotal: 10 * gb,
                swapUsed: 5 * gb // 5 GB > 4 GB warning threshold
            )
        )

        _ = detector.process(metrics)
        let t0 = Date(timeIntervalSince1970: 1000)
        _ = detector.tick(at: t0)

        // Should be in elevated state (5 GB > 4 GB warning)
        if case .elevated = detector.currentState {
            // expected
        } else {
            Issue.record("Expected .elevated, got \(detector.currentState)")
        }
    }
}
