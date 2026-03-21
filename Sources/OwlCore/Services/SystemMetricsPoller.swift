import Foundation

/// Periodically polls system CPU and memory metrics.
///
/// Uses two-sample delta calculation for CPU usage. Exposes
/// the latest `SystemMetrics` snapshot.
public actor SystemMetricsPoller {

    // MARK: - Properties

    /// The latest metrics snapshot.
    public private(set) var currentMetrics: SystemMetrics = .zero

    /// Whether the poller is actively running.
    public private(set) var isRunning = false
    public private(set) var samplingMode: MetricsSamplingMode

    private let provider: MetricsProvider

    // Previous CPU sample for delta calculation
    private var prevTicks = CPUTicks(
        user: 0, system: 0, idle: 0, nice: 0
    )

    // Extended providers
    private let perCoreProvider = PerCoreCPUProvider()
    private let smcProvider = SMCTemperatureProvider()
    private let hidProvider = HIDTemperatureProvider()
    private let swapProvider = SwapProvider()
    private let diskProvider = DiskMetricsProvider()
    private let batteryProvider = BatteryProvider()
    private let networkProvider = NetworkMetricsProvider()
    private let processProvider = TopProcessProvider()

    // Per-core previous ticks for delta
    private var prevCoreTicks: [CoreCPUTicks] = []

    // Network previous counters
    private var prevNetBytes: (
        bytesIn: UInt64, bytesOut: UInt64
    ) = (0, 0)
    private var prevNetTime: Date = .distantPast

    // Disk I/O previous counters
    private var prevDiskIO: (
        readBytes: UInt64, writeBytes: UInt64
    ) = (0, 0)
    private var prevDiskTime: Date = .distantPast

    // Previous process snapshot for CPU delta (full snapshot)
    private var prevProcessSnapshots: [ProcessSnapshot] = []
    private var prevProcessTime: Date = .distantPast
    private var lastTopProcessesRefresh: Date?

    // MARK: - Init

    /// Create a SystemMetricsPoller.
    /// - Parameters:
    ///   - interval: Polling interval in seconds (default 1.0).
    ///   - provider: Metrics data source (default: real Mach APIs).
    public init(
        interval: TimeInterval = 1.0,
        provider: MetricsProvider = MachMetricsProvider()
    ) {
        if interval >= 10 {
            self.samplingMode = .background
        } else {
            self.samplingMode = .foreground
        }
        self.provider = provider
    }

    // MARK: - Lifecycle

    /// Start polling. Takes an initial sample immediately.
    public func start() {
        guard !isRunning else { return }
        isRunning = true

        // Take initial CPU sample (baseline)
        prevTicks = provider.cpuTicks()

        // Update memory immediately
        let mem = provider.memoryInfo()
        currentMetrics = SystemMetrics(
            cpuUsage: 0,
            memoryTotal: mem.total,
            memoryUsed: mem.used
        )

        // Take initial baselines for extended metrics
        prevCoreTicks = perCoreProvider.coreTicks()
        prevNetBytes = networkProvider.totalBytes()
        prevNetTime = Date()
        prevDiskIO = diskProvider.diskIOBytes()
        prevDiskTime = Date()
        prevProcessSnapshots = processProvider.allProcessSnapshots()
        prevProcessTime = Date()

    }

    /// Stop polling.
    public func stop() {
        guard isRunning else { return }
        isRunning = false
    }

    public func setSamplingMode(
        _ mode: MetricsSamplingMode,
        refreshNow: Bool = false
    ) {
        let modeChanged = samplingMode != mode
        if modeChanged {
            samplingMode = mode
        }

        if refreshNow {
            sampleMetrics(forceRefresh: true)
        }
    }

    /// Force a single poll (for testing).
    public func pollOnce() {
        sampleMetrics(forceRefresh: true)
    }

    public static func interval(
        for mode: MetricsSamplingMode
    ) -> TimeInterval {
        profile(for: mode).interval
    }

    // MARK: - Internal

    static func profile(
        for mode: MetricsSamplingMode
    ) -> MetricsSamplingProfile {
        switch mode {
        case .background:
            MetricsSamplingProfile(
                interval: 10.0,
                includeLoadAverage: false,
                includePerCoreCPU: false,
                includeSwap: true,
                includeDisk: true,
                includeBattery: false,
                includeNetwork: false,
                includeTopProcesses: false,
                includeTemperatures: false
            )
        case .foreground:
            MetricsSamplingProfile(
                interval: 2.0,
                includeLoadAverage: true,
                includePerCoreCPU: true,
                includeSwap: true,
                includeDisk: true,
                includeBattery: true,
                includeNetwork: true,
                includeTopProcesses: true,
                includeTemperatures: true
            )
        }
    }

    static func shouldRefreshTopProcesses(
        now: Date,
        lastRefresh: Date?,
        currentCPUCount: Int,
        currentMemoryCount: Int,
        forceRefresh: Bool
    ) -> Bool {
        if forceRefresh
            || currentCPUCount == 0
            || currentMemoryCount == 0 {
            return true
        }

        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) >= 10
    }

    private func sampleMetrics(forceRefresh: Bool = false) {
        let profile = Self.profile(for: samplingMode)
        let cpuUsage = sampleCPU()
        let mem = provider.memoryInfo()
        let perCore = profile.includePerCoreCPU
            ? samplePerCoreCPU()
            : currentMetrics.perCoreCPU
        let load = profile.includeLoadAverage
            ? perCoreProvider.loadAverage()
            : currentMetrics.loadAverage
        let extMem = profile.includeSwap
            ? sampleExtendedMemory(mem: mem)
            : currentMetrics.extendedMemory

        let tempResult = sampleTemperatureData(profile: profile)

        let battery = profile.includeBattery
            ? batteryProvider.batteryInfo()
            : currentMetrics.battery
        let disk = profile.includeDisk
            ? sampleDisk()
            : currentMetrics.disk
        let network = profile.includeNetwork
            ? sampleNetwork()
            : currentMetrics.network
        let (topProcs, topMemProcs) = profile.includeTopProcesses
            ? sampleTopProcesses(forceRefresh: forceRefresh)
            : (currentMetrics.topProcesses,
               currentMetrics.topMemoryProcesses)
        let temps = profile.includeTemperatures
            ? sampleTemperatures(
                battery: battery,
                hidReadings: tempResult.hidReadings,
                smcTemperatures: tempResult.smcTemperatures,
                cpuTemperature: tempResult.cpuTemp
            )
            : currentMetrics.temperatures

        currentMetrics = SystemMetrics(
            cpuUsage: cpuUsage,
            memoryTotal: mem.total,
            memoryUsed: mem.used,
            perCoreCPU: perCore,
            cpuTemperature: tempResult.cpuTemp,
            loadAverage: load,
            extendedMemory: extMem,
            disk: disk,
            battery: battery,
            network: network,
            topProcesses: topProcs,
            topMemoryProcesses: topMemProcs,
            temperatures: temps
        )
    }

    private struct TemperatureData {
        let hidReadings: [String: Double]
        let smcTemperatures: [String: Double]
        let cpuTemp: Double?
    }

    private func sampleTemperatureData(
        profile: MetricsSamplingProfile
    ) -> TemperatureData {
        guard profile.includeTemperatures else {
            return TemperatureData(
                hidReadings: [:],
                smcTemperatures: [:],
                cpuTemp: currentMetrics.cpuTemperature
            )
        }

        let hidReadings = hidProvider.sensorReadings()
        let smcTemperatures = Dictionary(
            smcProvider.allTemperatures()
        ) { _, new in new }

        let cpuTemp = HIDTemperatureProvider.cpuTemperature(
            from: hidReadings
        ) ?? smcTemperatures["CPU"]

        return TemperatureData(
            hidReadings: hidReadings,
            smcTemperatures: smcTemperatures,
            cpuTemp: cpuTemp
        )
    }

    private func sampleCPU() -> Double {
        let ticks = provider.cpuTicks()
        let dUser = ticks.user &- prevTicks.user
        let dSystem = ticks.system &- prevTicks.system
        let dIdle = ticks.idle &- prevTicks.idle
        let dNice = ticks.nice &- prevTicks.nice
        let totalDelta = dUser + dSystem + dIdle + dNice
        prevTicks = ticks

        guard totalDelta > 0 else { return 0 }
        let activeD = Double(dUser + dSystem + dNice)
        return (activeD / Double(totalDelta)) * 100.0
    }

    private func samplePerCoreCPU() -> [CoreCPUUsage] {
        let coreTicks = perCoreProvider.coreTicks()
        let perCore = computePerCoreCPU(
            prev: prevCoreTicks, curr: coreTicks
        )
        prevCoreTicks = coreTicks
        return perCore
    }

    private func sampleExtendedMemory(
        mem: MemoryInfo
    ) -> ExtendedMemoryInfo {
        let swap = swapProvider.swapUsage()
        return ExtendedMemoryInfo(
            total: mem.total,
            used: mem.used,
            cached: mem.cached,
            available: mem.available,
            swapTotal: swap.total,
            swapUsed: swap.used,
            pageins: mem.pageins,
            pageouts: mem.pageouts
        )
    }
}

// MARK: - Sampling Helpers

extension SystemMetricsPoller {

    private func sampleDisk() -> DiskMetrics {
        let diskUsage = diskProvider.diskUsage()
        let diskIO = diskProvider.diskIOBytes()
        let now = Date()
        let elapsed = now.timeIntervalSince(prevDiskTime)
        defer {
            prevDiskIO = diskIO
            prevDiskTime = now
        }

        var readRate: Double = 0
        var writeRate: Double = 0
        if elapsed > 0 {
            let dRead = diskIO.readBytes >= prevDiskIO.readBytes
                ? diskIO.readBytes - prevDiskIO.readBytes : 0
            let dWrite =
                diskIO.writeBytes >= prevDiskIO.writeBytes
                ? diskIO.writeBytes - prevDiskIO.writeBytes : 0
            readRate = Double(dRead) / elapsed
            writeRate = Double(dWrite) / elapsed
        }

        return DiskMetrics(
            totalBytes: diskUsage.total,
            usedBytes: diskUsage.used,
            readBytesPerSec: readRate,
            writeBytesPerSec: writeRate
        )
    }

    private func sampleNetwork() -> NetworkMetrics {
        let netBytes = networkProvider.totalBytes()
        let ifInfo = networkProvider.activeInterfaceInfo()
        let now = Date()
        let elapsed = now.timeIntervalSince(prevNetTime)
        defer {
            prevNetBytes = netBytes
            prevNetTime = now
        }

        guard elapsed > 0 else {
            return NetworkMetrics(
                bytesInPerSec: 0,
                bytesOutPerSec: 0,
                activeInterface: ifInfo.name,
                localIP: ifInfo.ip
            )
        }
        let dIn = netBytes.bytesIn >= prevNetBytes.bytesIn
            ? netBytes.bytesIn - prevNetBytes.bytesIn : 0
        let dOut = netBytes.bytesOut >= prevNetBytes.bytesOut
            ? netBytes.bytesOut - prevNetBytes.bytesOut : 0
        return NetworkMetrics(
            bytesInPerSec: Double(dIn) / elapsed,
            bytesOutPerSec: Double(dOut) / elapsed,
            activeInterface: ifInfo.name,
            localIP: ifInfo.ip
        )
    }

    private func sampleTopProcesses(
        forceRefresh: Bool = false
    ) -> ([ProcessMetric], [ProcessMemoryMetric]) {
        let now = Date()
        guard Self.shouldRefreshTopProcesses(
            now: now,
            lastRefresh: lastTopProcessesRefresh,
            currentCPUCount: currentMetrics.topProcesses.count,
            currentMemoryCount: currentMetrics
                .topMemoryProcesses.count,
            forceRefresh: forceRefresh
        ) else {
            // When throttled, we intentionally keep the previous ranking and
            // baseline. The next refresh becomes a longer-window average,
            // which is the tradeoff that avoids a full process scan every poll.
            return (currentMetrics.topProcesses,
                    currentMetrics.topMemoryProcesses)
        }

        let curSnapshots = processProvider.allProcessSnapshots()
        let elapsed = now.timeIntervalSince(prevProcessTime)
        defer {
            prevProcessSnapshots = curSnapshots
            prevProcessTime = now
        }

        guard elapsed > 0 else { return ([], []) }

        let top = TopProcessProvider.computeCPUPercent(
            previous: prevProcessSnapshots,
            current: curSnapshots,
            interval: elapsed,
            coreCount: max(prevCoreTicks.count, 1)
        )
        let topMem = TopProcessProvider.computeTopMemory(
            snapshots: curSnapshots
        )
        lastTopProcessesRefresh = now
        return (top, topMem)
    }

    private func computePerCoreCPU(
        prev: [CoreCPUTicks],
        curr: [CoreCPUTicks]
    ) -> [CoreCPUUsage] {
        guard prev.count == curr.count else {
            return curr.map {
                CoreCPUUsage(id: $0.coreID, usage: 0)
            }
        }
        return zip(prev, curr).map { old, new in
            let dTotal = new.total &- old.total
            let dActive = new.active &- old.active
            let usage: Double
            if dTotal > 0 {
                usage = Double(dActive) / Double(dTotal)
                    * 100.0
            } else {
                usage = 0
            }
            return CoreCPUUsage(
                id: new.coreID, usage: usage
            )
        }
    }

    private func sampleTemperatures(
        battery: BatteryMetrics,
        hidReadings: [String: Double],
        smcTemperatures: [String: Double],
        cpuTemperature: Double?
    ) -> [TemperatureSensor] {
        // Build the same 3 summary rows as before: CPU, GPU, SSD.
        // On Apple Silicon, HID provides reliable CPU/GPU averages;
        // SMC provides SSD and serves as fallback for Intel.
        var sensors: [TemperatureSensor] = []

        // CPU — prefer HID die average, fall back to SMC
        if let cpu = cpuTemperature {
            sensors.append(TemperatureSensor(label: "CPU", celsius: cpu))
        }

        // GPU — prefer HID, fall back to SMC
        if let gpu = HIDTemperatureProvider.gpuTemperature(
            from: hidReadings
        ) ?? smcTemperatures["GPU"] {
            sensors.append(TemperatureSensor(label: "GPU", celsius: gpu))
        }

        // SSD — SMC only (HID doesn't provide a useful SSD reading)
        if let ssd = smcTemperatures["SSD"] {
            sensors.append(TemperatureSensor(label: "SSD", celsius: ssd))
        }

        // Battery temperature from IOKit power source
        if let battTemp = battery.temperature {
            sensors.append(
                TemperatureSensor(
                    label: "Battery", celsius: battTemp
                )
            )
        }
        return sensors
    }
}
