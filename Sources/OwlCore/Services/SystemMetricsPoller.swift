import Foundation

/// Snapshot of system resource metrics.
public struct SystemMetrics: Sendable, Equatable {
    /// CPU usage as a percentage (0.0 to 100.0).
    public let cpuUsage: Double

    /// Total physical memory in bytes.
    public let memoryTotal: UInt64

    /// Used memory in bytes (active + wired + compressed).
    public let memoryUsed: UInt64

    /// Memory pressure as a percentage (0.0 to 100.0).
    public var memoryPressure: Double {
        guard memoryTotal > 0 else { return 0 }
        return Double(memoryUsed) / Double(memoryTotal) * 100.0
    }

    public init(
        cpuUsage: Double,
        memoryTotal: UInt64,
        memoryUsed: UInt64
    ) {
        self.cpuUsage = cpuUsage
        self.memoryTotal = memoryTotal
        self.memoryUsed = memoryUsed
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

    public init(total: UInt64, used: UInt64) {
        self.total = total
        self.used = used
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

        return MemoryInfo(
            total: total,
            used: active + wired + compressed
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
        // CPU delta
        let ticks = provider.cpuTicks()
        let dUser = ticks.user &- prevTicks.user
        let dSystem = ticks.system &- prevTicks.system
        let dIdle = ticks.idle &- prevTicks.idle
        let dNice = ticks.nice &- prevTicks.nice
        let totalDelta = dUser + dSystem + dIdle + dNice

        let cpuUsage: Double
        if totalDelta > 0 {
            let activeD = Double(dUser + dSystem + dNice)
            cpuUsage = (activeD / Double(totalDelta)) * 100.0
        } else {
            cpuUsage = 0
        }

        prevTicks = ticks

        // Memory
        let mem = provider.memoryInfo()

        currentMetrics = SystemMetrics(
            cpuUsage: cpuUsage,
            memoryTotal: mem.total,
            memoryUsed: mem.used
        )
    }
}
