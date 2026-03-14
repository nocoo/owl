import Foundation
import Testing
@testable import OwlCore

@Suite("DiskUsagePattern")
struct DiskUsagePatternTests {

    @Test("has correct ID")
    func correctID() {
        #expect(DiskUsagePattern.id == "disk_usage")
    }

    @Test("creates detector with correct ID")
    func detectorID() {
        let detector = DiskUsagePattern.makeDetector()
        #expect(detector.id == "disk_usage")
    }

    @Test("detector starts in normal state")
    func initialState() {
        let detector = DiskUsagePattern.makeDetector()
        #expect(detector.currentState == .normal)
    }

    @Test("extracts disk usage correctly")
    func extractsDiskUsage() {
        let detector = DiskUsagePattern.makeDetector()
        let total: UInt64 = 500_000_000_000
        let used = UInt64(Double(total) * 0.90) // 90%
        let metrics = SystemMetrics(
            cpuUsage: 10,
            memoryTotal: 16_000_000_000,
            memoryUsed: 8_000_000_000,
            disk: DiskMetrics(
                totalBytes: total,
                usedBytes: used,
                readBytesPerSec: 0,
                writeBytesPerSec: 0
            )
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
