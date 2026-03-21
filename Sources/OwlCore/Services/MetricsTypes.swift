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

    /// Top processes by resident memory.
    public let topMemoryProcesses: [ProcessMemoryMetric]

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
        topMemoryProcesses: [ProcessMemoryMetric] = [],
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
        self.topMemoryProcesses = topMemoryProcesses
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
        total: UInt64,
        used: UInt64,
        cached: UInt64 = 0,
        available: UInt64 = 0,
        pageins: UInt64 = 0,
        pageouts: UInt64 = 0
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
