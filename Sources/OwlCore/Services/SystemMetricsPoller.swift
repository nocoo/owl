import Foundation

public enum MetricsSamplingMode: Sendable, Equatable {
    case background
    case foreground
}

struct MetricsSamplingProfile: Sendable, Equatable {
    let interval: TimeInterval
    let includeLoadAverage: Bool
    let includePerCoreCPU: Bool
    let includeSwap: Bool
    let includeDisk: Bool
    let includeBattery: Bool
    let includeNetwork: Bool
    let includeTopProcesses: Bool
    let includeTemperatures: Bool
}

/// Snapshot of system resource metrics.
public struct SystemMetrics: Sendable, Equatable {
    /// CPU usage as a percentage (0.0 to 100.0).
    public let cpuUsage: Double

    /// Total physical memory in bytes.
    public let memoryTotal: UInt64

    /// Used memory in bytes (active + wired + compressed).
    public let memoryUsed: UInt64

    /// Per-core CPU usage (may be empty if unavailable).
    public let perCoreCPU: [CoreCPUUsage]

    /// CPU temperature in Celsius (nil if unavailable).
    public let cpuTemperature: Double?

    /// Load averages (1, 5, 15 min).
    public let loadAverage: LoadAverage

    /// Extended memory info with swap.
    public let extendedMemory: ExtendedMemoryInfo

    /// Disk usage and I/O.
    public let disk: DiskMetrics

    /// Battery / power info.
    public let battery: BatteryMetrics

    /// Network throughput.
    public let network: NetworkMetrics

    /// Top processes by CPU.
    public let topProcesses: [ProcessMetric]

    /// Temperature sensors (CPU, GPU, SSD, Battery…).
    public let temperatures: [TemperatureSensor]

    /// Memory pressure as a percentage (0.0 to 100.0).
    public var memoryPressure: Double {
        guard memoryTotal > 0 else { return 0 }
        return Double(memoryUsed) / Double(memoryTotal) * 100.0
    }

    public init(
        cpuUsage: Double,
        memoryTotal: UInt64,
        memoryUsed: UInt64,
        perCoreCPU: [CoreCPUUsage] = [],
        cpuTemperature: Double? = nil,
        loadAverage: LoadAverage = .zero,
        extendedMemory: ExtendedMemoryInfo = .zero,
        disk: DiskMetrics = .zero,
        battery: BatteryMetrics = .unavailable,
        network: NetworkMetrics = .zero,
        topProcesses: [ProcessMetric] = [],
        temperatures: [TemperatureSensor] = []
    ) {
        self.cpuUsage = cpuUsage
        self.memoryTotal = memoryTotal
        self.memoryUsed = memoryUsed
        self.perCoreCPU = perCoreCPU
        self.cpuTemperature = cpuTemperature
        self.loadAverage = loadAverage
        self.extendedMemory = extendedMemory
        self.disk = disk
        self.battery = battery
        self.network = network
        self.topProcesses = topProcesses
        self.temperatures = temperatures
    }

    /// Default "zero" metrics for initial state.
    public static let zero = SystemMetrics(
        cpuUsage: 0,
        memoryTotal: 0,
        memoryUsed: 0
    )
}

/// CPU tick counts from the kernel.
public struct CPUTicks: Sendable, Equatable {
    public let user: UInt32
    public let system: UInt32
    public let idle: UInt32
    public let nice: UInt32

    public init(
        user: UInt32,
        system: UInt32,
        idle: UInt32,
        nice: UInt32
    ) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    /// Total ticks across all states.
    public var total: UInt32 {
        user &+ system &+ idle &+ nice
    }

    /// Active (non-idle) ticks.
    public var active: UInt32 {
        user &+ system &+ nice
    }
}

/// Memory usage info.
public struct MemoryInfo: Sendable, Equatable {
    public let total: UInt64
    public let used: UInt64
    public let cached: UInt64
    public let available: UInt64
    /// Cumulative page-in count since boot.
    public let pageins: UInt64
    /// Cumulative page-out count since boot.
    public let pageouts: UInt64

    public init(
        total: UInt64, used: UInt64,
        cached: UInt64 = 0, available: UInt64 = 0,
        pageins: UInt64 = 0, pageouts: UInt64 = 0
    ) {
        self.total = total
        self.used = used
        self.cached = cached
        self.available = available
        self.pageins = pageins
        self.pageouts = pageouts
    }
}

/// Protocol for sourcing raw CPU/memory data. Enables testing without Mach calls.
public protocol MetricsProvider: Sendable {
    /// Returns CPU tick counts.
    func cpuTicks() -> CPUTicks

    /// Returns memory info.
    func memoryInfo() -> MemoryInfo
}

/// Real implementation using Mach host_statistics APIs.
public struct MachMetricsProvider: MetricsProvider {
    public init() {}

    public func cpuTicks() -> CPUTicks {
        var loadInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride
            / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &loadInfo) {
            $0.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { ptr in
                host_statistics(
                    mach_host_self(),
                    HOST_CPU_LOAD_INFO,
                    ptr,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        }

        return CPUTicks(
            user: loadInfo.cpu_ticks.0,
            system: loadInfo.cpu_ticks.1,
            idle: loadInfo.cpu_ticks.2,
            nice: loadInfo.cpu_ticks.3
        )
    }

    public func memoryInfo() -> MemoryInfo {
        let total = ProcessInfo.processInfo.physicalMemory

        var vmStats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride
            / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { ptr in
                host_statistics64(
                    mach_host_self(),
                    HOST_VM_INFO64,
                    ptr,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryInfo(total: total, used: 0)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(vmStats.active_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count)
            * pageSize
        let purgeable = UInt64(vmStats.purgeable_count)
            * pageSize
        let external = UInt64(vmStats.external_page_count)
            * pageSize
        let free = UInt64(vmStats.free_count) * pageSize

        let used = active + wired + compressed
        // File-backed pages (cached) — external + purgeable
        let cached = external + purgeable
        // Available = free + purgeable + (inactive pages that can be reclaimed)
        let inactive = UInt64(vmStats.inactive_count) * pageSize
        let available = free + inactive + purgeable

        // Cumulative page-in / page-out counts
        let pageins = UInt64(vmStats.pageins)
        let pageouts = UInt64(vmStats.pageouts)

        return MemoryInfo(
            total: total,
            used: used,
            cached: cached,
            available: available,
            pageins: pageins,
            pageouts: pageouts
        )
    }
}

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
    private var interval: TimeInterval
    private var pollTask: Task<Void, Never>?

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
        self.interval = interval
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

        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    /// Stop polling.
    public func stop() {
        guard isRunning else { return }
        pollTask?.cancel()
        pollTask = nil
        isRunning = false
    }

    public func setSamplingMode(
        _ mode: MetricsSamplingMode,
        refreshNow: Bool = false
    ) {
        samplingMode = mode
        interval = Self.profile(for: mode).interval

        if refreshNow {
            sampleMetrics(forceRefresh: true)
        }
    }

    /// Force a single poll (for testing).
    public func pollOnce() {
        sampleMetrics(forceRefresh: true)
    }

    // MARK: - Internal

    private func pollLoop() async {
        while !Task.isCancelled {
            let ns = UInt64(interval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { break }
            sampleMetrics()
        }
    }

    static func profile(
        for mode: MetricsSamplingMode
    ) -> MetricsSamplingProfile {
        switch mode {
        case .background:
            MetricsSamplingProfile(
                interval: 10.0,
                includeLoadAverage: false,
                includePerCoreCPU: false,
                includeSwap: false,
                includeDisk: false,
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

        var hidReadings: [String: Double] = [:]
        var smcTemperatures: [String: Double] = [:]
        if profile.includeTemperatures {
            hidReadings = hidProvider.sensorReadings()
            smcTemperatures = Dictionary(
                uniqueKeysWithValues: smcProvider.allTemperatures()
            )
        }

        // Prefer HID on Apple Silicon (reliable), fall back to SMC.
        let temp = profile.includeTemperatures
            ? HIDTemperatureProvider.cpuTemperature(
                from: hidReadings
            ) ?? smcTemperatures["CPU"]
            : currentMetrics.cpuTemperature

        let battery = profile.includeBattery
            ? batteryProvider.batteryInfo()
            : currentMetrics.battery
        let disk = profile.includeDisk
            ? sampleDisk()
            : currentMetrics.disk
        let network = profile.includeNetwork
            ? sampleNetwork()
            : currentMetrics.network
        let topProcs = profile.includeTopProcesses
            ? sampleTopProcesses(forceRefresh: forceRefresh)
            : currentMetrics.topProcesses
        let temps = profile.includeTemperatures
            ? sampleTemperatures(
                battery: battery,
                hidReadings: hidReadings,
                smcTemperatures: smcTemperatures,
                cpuTemperature: temp
            )
            : currentMetrics.temperatures

        currentMetrics = SystemMetrics(
            cpuUsage: cpuUsage,
            memoryTotal: mem.total,
            memoryUsed: mem.used,
            perCoreCPU: perCore,
            cpuTemperature: temp,
            loadAverage: load,
            extendedMemory: extMem,
            disk: disk,
            battery: battery,
            network: network,
            topProcesses: topProcs,
            temperatures: temps
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
    ) -> [ProcessMetric] {
        let curSnapshots = processProvider.allProcessSnapshots()
        let now = Date()
        let elapsed = now.timeIntervalSince(prevProcessTime)
        defer {
            prevProcessSnapshots = curSnapshots
            prevProcessTime = now
        }

        guard elapsed > 0 else { return [] }

        return TopProcessProvider.computeCPUPercent(
            previous: prevProcessSnapshots,
            current: curSnapshots,
            interval: elapsed,
            coreCount: max(prevCoreTicks.count, 1)
        )
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
