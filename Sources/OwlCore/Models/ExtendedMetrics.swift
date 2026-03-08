import Foundation

/// Per-core CPU usage snapshot.
public struct CoreCPUUsage: Sendable, Equatable, Identifiable {
    public let id: Int
    public let usage: Double // 0-100%

    public init(id: Int, usage: Double) {
        self.id = id
        self.usage = usage
    }
}

/// Per-core CPU tick counts from the kernel.
public struct CoreCPUTicks: Sendable, Equatable {
    public let coreID: Int
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64
    public let nice: UInt64

    public init(
        coreID: Int,
        user: UInt64,
        system: UInt64,
        idle: UInt64,
        nice: UInt64
    ) {
        self.coreID = coreID
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    public var total: UInt64 { user &+ system &+ idle &+ nice }
    public var active: UInt64 { user &+ system &+ nice }
}

/// Load averages (1, 5, 15 minute) with core topology.
public struct LoadAverage: Sendable, Equatable {
    public let one: Double
    public let five: Double
    public let fifteen: Double
    public let performanceCores: Int
    public let efficiencyCores: Int

    public init(
        one: Double, five: Double, fifteen: Double,
        performanceCores: Int = 0, efficiencyCores: Int = 0
    ) {
        self.one = one
        self.five = five
        self.fifteen = fifteen
        self.performanceCores = performanceCores
        self.efficiencyCores = efficiencyCores
    }

    public static let zero = LoadAverage(
        one: 0, five: 0, fifteen: 0
    )
}

/// Extended memory info including swap, cached, and available.
public struct ExtendedMemoryInfo: Sendable, Equatable {
    public let total: UInt64
    public let used: UInt64
    public let cached: UInt64
    public let available: UInt64
    public let swapTotal: UInt64
    public let swapUsed: UInt64
    /// Cumulative page-in count since boot (vm_statistics64).
    public let pageins: UInt64
    /// Cumulative page-out count since boot (vm_statistics64).
    public let pageouts: UInt64

    public init(
        total: UInt64,
        used: UInt64,
        cached: UInt64 = 0,
        available: UInt64 = 0,
        swapTotal: UInt64,
        swapUsed: UInt64,
        pageins: UInt64 = 0,
        pageouts: UInt64 = 0
    ) {
        self.total = total
        self.used = used
        self.cached = cached
        self.available = available
        self.swapTotal = swapTotal
        self.swapUsed = swapUsed
        self.pageins = pageins
        self.pageouts = pageouts
    }

    public var free: UInt64 {
        total > used ? total - used : 0
    }

    public var freePercent: Double {
        guard total > 0 else { return 0 }
        return Double(free) / Double(total) * 100
    }

    public var usedPercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }

    public var swapPercent: Double {
        guard swapTotal > 0 else { return 0 }
        return Double(swapUsed) / Double(swapTotal) * 100
    }

    public static let zero = ExtendedMemoryInfo(
        total: 0, used: 0, cached: 0, available: 0,
        swapTotal: 0, swapUsed: 0, pageins: 0, pageouts: 0
    )
}

/// Disk usage and I/O throughput.
public struct DiskMetrics: Sendable, Equatable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let readBytesPerSec: Double
    public let writeBytesPerSec: Double

    public init(
        totalBytes: UInt64,
        usedBytes: UInt64,
        readBytesPerSec: Double,
        writeBytesPerSec: Double
    ) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.readBytesPerSec = readBytesPerSec
        self.writeBytesPerSec = writeBytesPerSec
    }

    public var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    public var freeBytes: UInt64 {
        totalBytes > usedBytes ? totalBytes - usedBytes : 0
    }

    public static let zero = DiskMetrics(
        totalBytes: 0,
        usedBytes: 0,
        readBytesPerSec: 0,
        writeBytesPerSec: 0
    )
}

/// Battery / power information.
public struct BatteryMetrics: Sendable, Equatable {
    public let level: Double // 0-100%
    public let health: Double // 0-100% (design capacity ratio)
    public let cycleCount: Int
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let temperature: Double? // Celsius
    public let timeRemaining: Int? // minutes
    public let condition: String // "Normal", "Service Recommended"
    public let wattage: Double? // Watts (positive = charging, negative = discharging)

    public init(
        level: Double,
        health: Double,
        cycleCount: Int,
        isCharging: Bool,
        isPluggedIn: Bool,
        temperature: Double?,
        timeRemaining: Int?,
        condition: String,
        wattage: Double? = nil
    ) {
        self.level = level
        self.health = health
        self.cycleCount = cycleCount
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.temperature = temperature
        self.timeRemaining = timeRemaining
        self.condition = condition
        self.wattage = wattage
    }

    public var stateText: String {
        if isCharging { return L10n.tr(.batteryCharging) }
        if isPluggedIn { return L10n.tr(.batteryPluggedIn) }
        return L10n.tr(.batteryDischarging)
    }

    public static let unavailable = BatteryMetrics(
        level: 0,
        health: 0,
        cycleCount: 0,
        isCharging: false,
        isPluggedIn: false,
        temperature: nil,
        timeRemaining: nil,
        condition: "Unavailable"
    )
}

/// Network throughput with interface info.
public struct NetworkMetrics: Sendable, Equatable {
    public let bytesInPerSec: Double
    public let bytesOutPerSec: Double
    public let activeInterface: String // e.g. "en0", "utun3"
    public let localIP: String // e.g. "192.168.31.141"

    public init(
        bytesInPerSec: Double,
        bytesOutPerSec: Double,
        activeInterface: String = "",
        localIP: String = ""
    ) {
        self.bytesInPerSec = bytesInPerSec
        self.bytesOutPerSec = bytesOutPerSec
        self.activeInterface = activeInterface
        self.localIP = localIP
    }

    public static let zero = NetworkMetrics(
        bytesInPerSec: 0, bytesOutPerSec: 0,
        activeInterface: "", localIP: ""
    )
}

/// A single process entry for top processes display.
public struct ProcessMetric: Sendable, Equatable, Identifiable {
    public let id: Int32 // pid
    public let name: String
    public let cpuPercent: Double

    public init(id: Int32, name: String, cpuPercent: Double) {
        self.id = id
        self.name = name
        self.cpuPercent = cpuPercent
    }
}

/// A named temperature sensor reading.
public struct TemperatureSensor: Sendable, Equatable, Identifiable {
    public let id: String // label used as ID
    public let label: String
    public let celsius: Double

    public init(label: String, celsius: Double) {
        self.id = label
        self.label = label
        self.celsius = celsius
    }
}
