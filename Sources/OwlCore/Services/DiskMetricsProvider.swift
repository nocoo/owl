import Darwin
import Foundation
import IOKit

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

    /// Returns cumulative disk I/O bytes (read, written) via IOKit.
    public func diskIOBytes() -> (
        readBytes: UInt64, writeBytes: UInt64
    ) {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault, matching, &iterator
        )
        guard result == KERN_SUCCESS else { return (0, 0) }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        var drive = IOIteratorNext(iterator)
        while drive != 0 {
            defer { IOObjectRelease(drive) }

            var props: Unmanaged<CFMutableDictionary>?
            let kr = IORegistryEntryCreateCFProperties(
                drive,
                &props,
                kCFAllocatorDefault,
                0
            )
            if kr == KERN_SUCCESS,
                let dict = props?.takeRetainedValue()
                    as? [String: Any],
                let stats = dict["Statistics"]
                    as? [String: Any] {
                if let rb = stats["Bytes (Read)"] as? UInt64 {
                    totalRead += rb
                }
                if let wb = stats["Bytes (Write)"] as? UInt64 {
                    totalWrite += wb
                }
            }

            drive = IOIteratorNext(iterator)
        }

        return (totalRead, totalWrite)
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
