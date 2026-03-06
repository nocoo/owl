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

/// Load averages (1, 5, 15 minute).
public struct LoadAverage: Sendable, Equatable {
    public let one: Double
    public let five: Double
    public let fifteen: Double

    public init(one: Double, five: Double, fifteen: Double) {
        self.one = one
        self.five = five
        self.fifteen = fifteen
    }

    public static let zero = LoadAverage(
        one: 0, five: 0, fifteen: 0
    )
}

/// Extended memory info including swap.
public struct ExtendedMemoryInfo: Sendable, Equatable {
    public let total: UInt64
    public let used: UInt64
    public let swapTotal: UInt64
    public let swapUsed: UInt64

    public init(
        total: UInt64,
        used: UInt64,
        swapTotal: UInt64,
        swapUsed: UInt64
    ) {
        self.total = total
        self.used = used
        self.swapTotal = swapTotal
        self.swapUsed = swapUsed
    }

    public var free: UInt64 {
        total > used ? total - used : 0
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
        total: 0, used: 0, swapTotal: 0, swapUsed: 0
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

    public init(
        level: Double,
        health: Double,
        cycleCount: Int,
        isCharging: Bool,
        isPluggedIn: Bool,
        temperature: Double?,
        timeRemaining: Int?,
        condition: String
    ) {
        self.level = level
        self.health = health
        self.cycleCount = cycleCount
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.temperature = temperature
        self.timeRemaining = timeRemaining
        self.condition = condition
    }

    public var stateText: String {
        if isCharging { return "Charging" }
        if isPluggedIn { return "Plugged In" }
        return "Discharging"
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

/// Network throughput.
public struct NetworkMetrics: Sendable, Equatable {
    public let bytesInPerSec: Double
    public let bytesOutPerSec: Double

    public init(
        bytesInPerSec: Double,
        bytesOutPerSec: Double
    ) {
        self.bytesInPerSec = bytesInPerSec
        self.bytesOutPerSec = bytesOutPerSec
    }

    public static let zero = NetworkMetrics(
        bytesInPerSec: 0, bytesOutPerSec: 0
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
