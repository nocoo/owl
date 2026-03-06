import Foundation

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
        topProcesses: [ProcessMetric] = []
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

    public init(
        total: UInt64, used: UInt64,
        cached: UInt64 = 0, available: UInt64 = 0
    ) {
        self.total = total
        self.used = used
        self.cached = cached
        self.available = available
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

        return MemoryInfo(
            total: total,
            used: used,
            cached: cached,
            available: available
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

    private let provider: MetricsProvider
    private let interval: TimeInterval
    private var pollTask: Task<Void, Never>?

    // Previous CPU sample for delta calculation
    private var prevTicks = CPUTicks(
        user: 0, system: 0, idle: 0, nice: 0
    )

    // Extended providers
    private let perCoreProvider = PerCoreCPUProvider()
    private let smcProvider = SMCTemperatureProvider()
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

    // Previous process snapshot for CPU delta
    private var prevProcesses: [ProcessMetric] = []

    // MARK: - Init

    /// Create a SystemMetricsPoller.
    /// - Parameters:
    ///   - interval: Polling interval in seconds (default 2.0).
    ///   - provider: Metrics data source (default: real Mach APIs).
    public init(
        interval: TimeInterval = 2.0,
        provider: MetricsProvider = MachMetricsProvider()
    ) {
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
        prevProcesses = processProvider.topProcesses()

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

    /// Force a single poll (for testing).
    public func pollOnce() {
        sampleMetrics()
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

    private func sampleMetrics() {
        let cpuUsage = sampleCPU()
        let mem = provider.memoryInfo()
        let perCore = samplePerCoreCPU()
        let temp = smcProvider.cpuTemperature()
        let load = perCoreProvider.loadAverage()
        let extMem = sampleExtendedMemory(mem: mem)
        let disk = sampleDisk()
        let battery = batteryProvider.batteryInfo()
        let network = sampleNetwork()
        let topProcs = sampleTopProcesses()

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
            topProcesses: Array(topProcs.prefix(5))
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
            swapUsed: swap.used
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

    private func sampleTopProcesses() -> [ProcessMetric] {
        let curProcesses = processProvider.topProcesses()
        let topProcs = TopProcessProvider.computeCPUPercent(
            previous: prevProcesses,
            current: curProcesses,
            interval: interval,
            coreCount: max(prevCoreTicks.count, 1)
        )
        prevProcesses = curProcesses
        return topProcs
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
}
