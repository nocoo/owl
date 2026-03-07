import SwiftUI
import Testing
@testable import OwlCore

@Suite("MetricHelpers")
struct MetricHelpersTests {

    // MARK: - thresholdColor

    @Test func thresholdColorGreenBelow50() {
        let color = thresholdColor(30)
        #expect(color == OwlPalette.green)
    }

    @Test func thresholdColorYellowAt50() {
        let color = thresholdColor(50)
        #expect(color == OwlPalette.amber)
    }

    @Test func thresholdColorYellowAt79() {
        let color = thresholdColor(79)
        #expect(color == OwlPalette.amber)
    }

    @Test func thresholdColorRedAt80() {
        let color = thresholdColor(80)
        #expect(color == OwlPalette.red)
    }

    @Test func thresholdColorCustomThresholds() {
        let color = thresholdColor(60, yellow: 70, red: 90)
        #expect(color == OwlPalette.green)
    }

    @Test func thresholdColorCustomYellow() {
        let color = thresholdColor(75, yellow: 70, red: 90)
        #expect(color == OwlPalette.amber)
    }

    @Test func thresholdColorCustomRed() {
        let color = thresholdColor(95, yellow: 70, red: 90)
        #expect(color == OwlPalette.red)
    }

    // MARK: - formatBytes

    @Test func formatBytesSmallMB() {
        let result = formatBytes(500_000_000)
        #expect(result == "477 MB")
    }

    @Test func formatBytesOneGB() {
        let result = formatBytes(1_073_741_824)
        #expect(result == "1.0 GB")
    }

    @Test func formatBytesTenGB() {
        let result = formatBytes(10_737_418_240)
        #expect(result == "10.0G")
    }

    @Test func formatBytesHundredGB() {
        let result = formatBytes(107_374_182_400)
        #expect(result == "100G")
    }

    @Test func formatBytesZero() {
        let result = formatBytes(0)
        #expect(result == "0 MB")
    }

    // MARK: - formatThroughput

    @Test func formatThroughputBytesPerSec() {
        let result = formatThroughput(512)
        #expect(result == "512 B/s")
    }

    @Test func formatThroughputKBPerSec() {
        let result = formatThroughput(51_200)
        #expect(result == "50 KB/s")
    }

    @Test func formatThroughputMBPerSec() {
        let result = formatThroughput(5_242_880)
        #expect(result == "5.0 MB/s")
    }

    @Test func formatThroughputZero() {
        let result = formatThroughput(0)
        #expect(result == "0 B/s")
    }
}
