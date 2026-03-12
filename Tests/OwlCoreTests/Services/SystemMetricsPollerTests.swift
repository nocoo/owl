import Foundation
import Testing
@testable import OwlCore

// MARK: - Mock MetricsProvider

/// Mock provider that returns configurable CPU ticks and memory values.
final class MockMetricsProvider: MetricsProvider, @unchecked Sendable {
    /// Sequential CPU tick values to return on each call.
    var cpuTickSequence: [CPUTicks] = []
    private var cpuCallIndex = 0

    var mockMemory = MemoryInfo(
        total: 16_000_000_000,
        used: 8_000_000_000
    )

    func cpuTicks() -> CPUTicks {
        guard cpuCallIndex < cpuTickSequence.count else {
            return CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        }
        let ticks = cpuTickSequence[cpuCallIndex]
        cpuCallIndex += 1
        return ticks
    }

    func memoryInfo() -> MemoryInfo {
        mockMemory
    }
}

// MARK: - SystemMetrics Tests

@Suite("SystemMetrics")
struct SystemMetricsTests {

    @Test func zeroMetrics() {
        let metrics = SystemMetrics.zero
        #expect(metrics.cpuUsage == 0)
        #expect(metrics.memoryTotal == 0)
        #expect(metrics.memoryUsed == 0)
        #expect(metrics.memoryPressure == 0)
    }

    @Test func memoryPressureCalculation() {
        let metrics = SystemMetrics(
            cpuUsage: 50,
            memoryTotal: 16_000_000_000,
            memoryUsed: 12_000_000_000
        )
        #expect(metrics.memoryPressure == 75.0)
    }

    @Test func memoryPressureZeroWhenTotalIsZero() {
        let metrics = SystemMetrics(
            cpuUsage: 0,
            memoryTotal: 0,
            memoryUsed: 0
        )
        #expect(metrics.memoryPressure == 0)
    }

    @Test func equatable() {
        let metricsA = SystemMetrics(
            cpuUsage: 50,
            memoryTotal: 16_000_000_000,
            memoryUsed: 8_000_000_000
        )
        let metricsB = SystemMetrics(
            cpuUsage: 50,
            memoryTotal: 16_000_000_000,
            memoryUsed: 8_000_000_000
        )
        #expect(metricsA == metricsB)
    }
}

// MARK: - SystemMetricsPoller Tests

@Suite("SystemMetricsPoller")
struct SystemMetricsPollerTests {

    @Test func foregroundProfileCollectsDetailedMetrics() {
        let profile = SystemMetricsPoller.profile(
            for: .foreground
        )
        #expect(profile.interval == 2.0)
        #expect(profile.includeLoadAverage)
        #expect(profile.includePerCoreCPU)
        #expect(profile.includeSwap)
        #expect(profile.includeDisk)
        #expect(profile.includeBattery)
        #expect(profile.includeNetwork)
        #expect(profile.includeTopProcesses)
        #expect(profile.includeTemperatures)
    }

    @Test func backgroundProfileDisablesExpensiveCollectors() {
        let profile = SystemMetricsPoller.profile(
            for: .background
        )
        #expect(profile.interval == 10.0)
        #expect(!profile.includeLoadAverage)
        #expect(!profile.includePerCoreCPU)
        #expect(!profile.includeSwap)
        #expect(!profile.includeDisk)
        #expect(!profile.includeBattery)
        #expect(!profile.includeNetwork)
        #expect(!profile.includeTopProcesses)
        #expect(!profile.includeTemperatures)
    }

    @Test func samplingIntervalsMatchProfiles() {
        #expect(SystemMetricsPoller.interval(for: .foreground) == 2.0)
        #expect(SystemMetricsPoller.interval(for: .background) == 10.0)
    }

    @Test func topProcessesRefreshesWhenForced() {
        let shouldRefresh = SystemMetricsPoller.shouldRefreshTopProcesses(
            now: Date(timeIntervalSince1970: 100),
            lastRefresh: Date(timeIntervalSince1970: 99),
            currentCount: 5,
            forceRefresh: true
        )
        #expect(shouldRefresh)
    }

    @Test func topProcessesRefreshesWhenEmpty() {
        let shouldRefresh = SystemMetricsPoller.shouldRefreshTopProcesses(
            now: Date(timeIntervalSince1970: 100),
            lastRefresh: Date(timeIntervalSince1970: 99),
            currentCount: 0,
            forceRefresh: false
        )
        #expect(shouldRefresh)
    }

    @Test func topProcessesSkipsRefreshWithinCooldown() {
        let shouldRefresh = SystemMetricsPoller.shouldRefreshTopProcesses(
            now: Date(timeIntervalSince1970: 105),
            lastRefresh: Date(timeIntervalSince1970: 100),
            currentCount: 5,
            forceRefresh: false
        )
        #expect(!shouldRefresh)
    }

    @Test func topProcessesRefreshesAfterCooldown() {
        let shouldRefresh = SystemMetricsPoller.shouldRefreshTopProcesses(
            now: Date(timeIntervalSince1970: 111),
            lastRefresh: Date(timeIntervalSince1970: 100),
            currentCount: 5,
            forceRefresh: false
        )
        #expect(shouldRefresh)
    }

    @Test func initialMetricsAreZero() async {
        let provider = MockMetricsProvider()
        provider.cpuTickSequence = [
            CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        ]
        let poller = SystemMetricsPoller(
            interval: 60,
            provider: provider
        )
        let metrics = await poller.currentMetrics
        #expect(metrics == .zero)
    }

    @Test func startsNotRunning() async {
        let provider = MockMetricsProvider()
        let poller = SystemMetricsPoller(
            interval: 60,
            provider: provider
        )
        #expect(await poller.isRunning == false)
    }

    @Test func startSetsRunning() async {
        let provider = MockMetricsProvider()
        provider.cpuTickSequence = [
            CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        ]
        let poller = SystemMetricsPoller(
            interval: 60,
            provider: provider
        )
        await poller.start()
        #expect(await poller.isRunning == true)
        await poller.stop()
    }

    @Test func stopSetsNotRunning() async {
        let provider = MockMetricsProvider()
        provider.cpuTickSequence = [
            CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        ]
        let poller = SystemMetricsPoller(
            interval: 60,
            provider: provider
        )
        await poller.start()
        await poller.stop()
        #expect(await poller.isRunning == false)
    }

    @Test func startTakesInitialMemorySample() async {
        let provider = MockMetricsProvider()
        provider.mockMemory = MemoryInfo(
            total: 16_000_000_000,
            used: 10_000_000_000
        )
        provider.cpuTickSequence = [
            CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        ]

        let poller = SystemMetricsPoller(
            interval: 60,
            provider: provider
        )

        await poller.start()
        let metrics = await poller.currentMetrics

        #expect(metrics.memoryTotal == 16_000_000_000)
        #expect(metrics.memoryUsed == 10_000_000_000)
        // CPU is 0 on first sample (baseline only)
        #expect(metrics.cpuUsage == 0)

        await poller.stop()
    }

    @Test func pollOnceCalculatesCPUDelta() async {
        let provider = MockMetricsProvider()
        // Sample 1 (baseline): user=100, system=50, idle=800, nice=50
        // Sample 2 (poll): user=200, system=100, idle=800, nice=50
        // Delta: user=100, system=50, idle=0, nice=0 -> total=150
        // Active = 100+50+0 = 150, CPU% = 150/150 * 100 = 100%
        provider.cpuTickSequence = [
            CPUTicks(user: 100, system: 50, idle: 800, nice: 50),
            CPUTicks(user: 200, system: 100, idle: 800, nice: 50)
        ]

        let poller = SystemMetricsPoller(
            interval: 60,
            provider: provider
        )

        await poller.start()
        await poller.pollOnce()
        let metrics = await poller.currentMetrics

        #expect(metrics.cpuUsage == 100.0)
        #expect(metrics.memoryTotal == 16_000_000_000)
        #expect(metrics.memoryUsed == 8_000_000_000)

        await poller.stop()
    }

    @Test func pollOnceCPU50Percent() async {
        let provider = MockMetricsProvider()
        // Baseline: user=100, system=0, idle=100, nice=0
        // Poll:     user=200, system=0, idle=200, nice=0
        // Delta: user=100, idle=100 -> total=200
        // Active = 100, CPU% = 100/200 * 100 = 50%
        provider.cpuTickSequence = [
            CPUTicks(user: 100, system: 0, idle: 100, nice: 0),
            CPUTicks(user: 200, system: 0, idle: 200, nice: 0)
        ]

        let poller = SystemMetricsPoller(
            interval: 60,
            provider: provider
        )

        await poller.start()
        await poller.pollOnce()
        let metrics = await poller.currentMetrics

        #expect(metrics.cpuUsage == 50.0)

        await poller.stop()
    }

    @Test func pollOnceWithZeroDeltaReturnsCPUZero() async {
        let provider = MockMetricsProvider()
        // Same ticks -> zero delta -> 0% CPU
        provider.cpuTickSequence = [
            CPUTicks(user: 100, system: 50, idle: 800, nice: 50),
            CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        ]

        let poller = SystemMetricsPoller(
            interval: 60,
            provider: provider
        )

        await poller.start()
        await poller.pollOnce()
        let metrics = await poller.currentMetrics

        #expect(metrics.cpuUsage == 0)

        await poller.stop()
    }

    @Test func multiplePolls() async {
        let provider = MockMetricsProvider()
        provider.cpuTickSequence = [
            CPUTicks(user: 100, system: 0, idle: 100, nice: 0),
            CPUTicks(user: 200, system: 0, idle: 200, nice: 0),
            CPUTicks(user: 400, system: 0, idle: 200, nice: 0)
        ]

        let poller = SystemMetricsPoller(
            interval: 60,
            provider: provider
        )

        await poller.start()
        await poller.pollOnce()
        var metrics = await poller.currentMetrics
        #expect(metrics.cpuUsage == 50.0)

        await poller.pollOnce()
        metrics = await poller.currentMetrics
        #expect(metrics.cpuUsage == 100.0)

        await poller.stop()
    }

    @Test func setSamplingModeRefreshNowTriggersImmediateSample() async {
        let provider = MockMetricsProvider()
        provider.cpuTickSequence = [
            CPUTicks(user: 100, system: 0, idle: 100, nice: 0),
            CPUTicks(user: 200, system: 0, idle: 200, nice: 0)
        ]
        let poller = SystemMetricsPoller(
            interval: 60,
            provider: provider
        )

        await poller.start()
        await poller.setSamplingMode(.foreground, refreshNow: true)

        let metrics = await poller.currentMetrics
        #expect(await poller.samplingMode == .foreground)
        #expect(metrics.cpuUsage == 50.0)

        await poller.stop()
    }

    @Test func setSamplingModeRefreshNowWorksEvenWhenModeUnchanged() async {
        let provider = MockMetricsProvider()
        provider.cpuTickSequence = [
            CPUTicks(user: 100, system: 0, idle: 100, nice: 0),
            CPUTicks(user: 200, system: 0, idle: 200, nice: 0),
            CPUTicks(user: 300, system: 0, idle: 300, nice: 0)
        ]
        let poller = SystemMetricsPoller(
            interval: 2,  // starts in foreground mode
            provider: provider
        )

        await poller.start()
        await poller.pollOnce()  // first sample: 50%

        // Same mode, but force refresh
        await poller.setSamplingMode(.foreground, refreshNow: true)

        let metrics = await poller.currentMetrics
        #expect(await poller.samplingMode == .foreground)
        #expect(metrics.cpuUsage == 50.0)  // second sample computed

        await poller.stop()
    }

    @Test func doubleStartIsNoOp() async {
        let provider = MockMetricsProvider()
        provider.cpuTickSequence = [
            CPUTicks(user: 100, system: 0, idle: 100, nice: 0),
            CPUTicks(user: 100, system: 0, idle: 100, nice: 0)
        ]
        let poller = SystemMetricsPoller(
            interval: 60,
            provider: provider
        )
        await poller.start()
        await poller.start() // should not crash or double-start
        #expect(await poller.isRunning == true)
        await poller.stop()
    }

    @Test func stopWhenNotRunningIsNoOp() async {
        let provider = MockMetricsProvider()
        let poller = SystemMetricsPoller(
            interval: 60,
            provider: provider
        )
        await poller.stop() // should not crash
        #expect(await poller.isRunning == false)
    }
}

// MARK: - MachMetricsProvider integration (real Mach calls)

@Suite("MachMetricsProvider")
struct MachMetricsProviderTests {

    @Test func cpuTicksReturnsNonZeroValues() {
        let provider = MachMetricsProvider()
        let ticks = provider.cpuTicks()
        // At least idle should be non-zero on any running system
        let total = ticks.user + ticks.system + ticks.idle + ticks.nice
        #expect(total > 0)
    }

    @Test func memoryInfoReturnsNonZeroTotal() {
        let provider = MachMetricsProvider()
        let mem = provider.memoryInfo()
        #expect(mem.total > 0)
        #expect(mem.used > 0)
        #expect(mem.used <= mem.total)
    }
}
