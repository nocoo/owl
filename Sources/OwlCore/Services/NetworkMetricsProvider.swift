import Darwin
import Foundation

/// Reads network I/O counters via getifaddrs, computes
/// throughput as a delta between samples.
public struct NetworkMetricsProvider: Sendable {
    public init() {}

    /// Raw byte counters for all physical interfaces.
    public func totalBytes() -> (
        bytesIn: UInt64, bytesOut: UInt64
    ) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0,
            let first = ifaddr
        else { return (0, 0) }
        defer { freeifaddrs(first) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = current {
            let name = String(cString: ifa.pointee.ifa_name)
            // Only count physical interfaces
            if isPhysicalInterface(name),
                let data = networkData(from: ifa.pointee) {
                totalIn += UInt64(data.ifi_ibytes)
                totalOut += UInt64(data.ifi_obytes)
            }
            current = ifa.pointee.ifa_next
        }

        return (totalIn, totalOut)
    }

    private func isPhysicalInterface(
        _ name: String
    ) -> Bool {
        name.hasPrefix("en") || name.hasPrefix("bridge")
    }

    private func networkData(
        from ifa: ifaddrs
    ) -> if_data? {
        guard ifa.ifa_addr?.pointee.sa_family
            == UInt8(AF_LINK),
            let data = ifa.ifa_data
        else { return nil }
        return data.assumingMemoryBound(
            to: if_data.self
        ).pointee
    }
}
