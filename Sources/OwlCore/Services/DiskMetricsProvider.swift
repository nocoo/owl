import Darwin
import Foundation

/// Reads disk usage (statvfs) and I/O stats (IOKit).
public struct DiskMetricsProvider: Sendable {
    public init() {}

    /// Disk usage for the root volume.
    public func diskUsage() -> (total: UInt64, used: UInt64) {
        var stat = statvfs()
        guard statvfs("/", &stat) == 0 else {
            return (0, 0)
        }
        let blockSize = UInt64(stat.f_frsize)
        let total = UInt64(stat.f_blocks) * blockSize
        let free = UInt64(stat.f_bavail) * blockSize
        let used = total > free ? total - free : 0
        return (total, used)
    }
}

/// Reads swap usage via sysctl.
public struct SwapProvider: Sendable {
    public init() {}

    /// Returns (swapTotal, swapUsed) in bytes.
    public func swapUsage() -> (total: UInt64, used: UInt64) {
        var xswUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname(
            "vm.swapusage", &xswUsage, &size, nil, 0
        )
        guard result == 0 else { return (0, 0) }
        return (xswUsage.xsu_total, xswUsage.xsu_used)
    }
}
