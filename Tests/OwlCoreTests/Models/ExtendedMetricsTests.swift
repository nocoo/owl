import Testing
@testable import OwlCore

@Suite("ExtendedMetrics")
struct ExtendedMetricsTests {

    // MARK: - CoreCPUUsage

    @Test func coreCPUUsageStoresValues() {
        let core = CoreCPUUsage(id: 3, usage: 65.5)
        #expect(core.id == 3)
        #expect(core.usage == 65.5)
    }

    @Test func coreCPUUsageIsIdentifiable() {
        let cores = [
            CoreCPUUsage(id: 0, usage: 10),
            CoreCPUUsage(id: 1, usage: 20)
        ]
        #expect(cores[0].id != cores[1].id)
    }

    // MARK: - CoreCPUTicks

    @Test func coreCPUTicksTotalAndActive() {
        let ticks = CoreCPUTicks(
            coreID: 0,
            user: 100,
            system: 50,
            idle: 200,
            nice: 10
        )
        #expect(ticks.total == 360)
        #expect(ticks.active == 160)
    }

    // MARK: - LoadAverage

    @Test func loadAverageZero() {
        let zero = LoadAverage.zero
        #expect(zero.one == 0)
        #expect(zero.five == 0)
        #expect(zero.fifteen == 0)
    }

    @Test func loadAverageStoresValues() {
        let load = LoadAverage(
            one: 1.5, five: 2.0, fifteen: 1.8
        )
        #expect(load.one == 1.5)
        #expect(load.five == 2.0)
        #expect(load.fifteen == 1.8)
    }

    // MARK: - ExtendedMemoryInfo

    @Test func extendedMemoryUsedPercent() {
        let mem = ExtendedMemoryInfo(
            total: 16_000_000_000,
            used: 8_000_000_000,
            swapTotal: 0,
            swapUsed: 0
        )
        #expect(mem.usedPercent == 50.0)
    }

    @Test func extendedMemoryFreeBytes() {
        let mem = ExtendedMemoryInfo(
            total: 16_000_000_000,
            used: 6_000_000_000,
            swapTotal: 0,
            swapUsed: 0
        )
        #expect(mem.free == 10_000_000_000)
    }

    @Test func extendedMemoryUsedPercentZeroTotal() {
        let mem = ExtendedMemoryInfo.zero
        #expect(mem.usedPercent == 0)
    }

    @Test func extendedMemorySwapPercent() {
        let mem = ExtendedMemoryInfo(
            total: 16_000_000_000,
            used: 8_000_000_000,
            swapTotal: 4_000_000_000,
            swapUsed: 1_000_000_000
        )
        #expect(mem.swapPercent == 25.0)
    }

    @Test func extendedMemorySwapPercentZeroTotal() {
        let mem = ExtendedMemoryInfo(
            total: 16_000_000_000,
            used: 8_000_000_000,
            swapTotal: 0,
            swapUsed: 0
        )
        #expect(mem.swapPercent == 0)
    }

    @Test func extendedMemoryFreeDoesNotUnderflow() {
        let mem = ExtendedMemoryInfo(
            total: 100,
            used: 200,
            swapTotal: 0,
            swapUsed: 0
        )
        #expect(mem.free == 0)
    }

    // MARK: - DiskMetrics

    @Test func diskMetricsUsedPercent() {
        let disk = DiskMetrics(
            totalBytes: 500_000_000_000,
            usedBytes: 250_000_000_000,
            readBytesPerSec: 100,
            writeBytesPerSec: 50
        )
        #expect(disk.usedPercent == 50.0)
    }

    @Test func diskMetricsFreeBytes() {
        let disk = DiskMetrics(
            totalBytes: 500_000_000_000,
            usedBytes: 200_000_000_000,
            readBytesPerSec: 0,
            writeBytesPerSec: 0
        )
        #expect(disk.freeBytes == 300_000_000_000)
    }

    @Test func diskMetricsZeroTotal() {
        let disk = DiskMetrics.zero
        #expect(disk.usedPercent == 0)
        #expect(disk.freeBytes == 0)
    }

    @Test func diskMetricsFreeDoesNotUnderflow() {
        let disk = DiskMetrics(
            totalBytes: 100,
            usedBytes: 200,
            readBytesPerSec: 0,
            writeBytesPerSec: 0
        )
        #expect(disk.freeBytes == 0)
    }

    // MARK: - BatteryMetrics

    @Test func batteryStateTextCharging() {
        let batt = BatteryMetrics(
            level: 80,
            health: 95,
            cycleCount: 150,
            isCharging: true,
            isPluggedIn: true,
            temperature: 35.0,
            timeRemaining: nil,
            condition: "Normal"
        )
        #expect(batt.stateText == "Charging")
    }

    @Test func batteryStateTextPluggedIn() {
        let batt = BatteryMetrics(
            level: 100,
            health: 95,
            cycleCount: 150,
            isCharging: false,
            isPluggedIn: true,
            temperature: nil,
            timeRemaining: nil,
            condition: "Normal"
        )
        #expect(batt.stateText == "Plugged In")
    }

    @Test func batteryStateTextDischarging() {
        let batt = BatteryMetrics(
            level: 60,
            health: 90,
            cycleCount: 300,
            isCharging: false,
            isPluggedIn: false,
            temperature: 40.0,
            timeRemaining: 180,
            condition: "Normal"
        )
        #expect(batt.stateText == "Discharging")
    }

    @Test func batteryUnavailable() {
        let batt = BatteryMetrics.unavailable
        #expect(batt.level == 0)
        #expect(batt.condition == "Unavailable")
    }

    // MARK: - NetworkMetrics

    @Test func networkMetricsZero() {
        let net = NetworkMetrics.zero
        #expect(net.bytesInPerSec == 0)
        #expect(net.bytesOutPerSec == 0)
    }

    @Test func networkMetricsStoresValues() {
        let net = NetworkMetrics(
            bytesInPerSec: 1_048_576,
            bytesOutPerSec: 524_288
        )
        #expect(net.bytesInPerSec == 1_048_576)
        #expect(net.bytesOutPerSec == 524_288)
    }

    // MARK: - ProcessMetric

    @Test func processMetricIsIdentifiable() {
        let proc = ProcessMetric(
            id: 1234, name: "safari", cpuPercent: 45.2
        )
        #expect(proc.id == 1234)
        #expect(proc.name == "safari")
        #expect(proc.cpuPercent == 45.2)
    }
}
