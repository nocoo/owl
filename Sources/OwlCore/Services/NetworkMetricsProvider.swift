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

    /// Returns the active network interface name and its local IP.
    public func activeInterfaceInfo() -> (
        name: String, ip: String
    ) {
        // Get default route interface from `route get default`
        let defaultIface = getDefaultInterface()

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0,
            let first = ifaddr
        else { return (defaultIface, "") }
        defer { freeifaddrs(first) }

        // Find IPv4 address for the active interface
        if let result = findIPv4Address(
            in: first, matching: defaultIface
        ) { return result }

        // Fallback: find any en0 IPv4
        if let result = findIPv4Address(
            in: first, matching: "en0"
        ) { return result }

        return (defaultIface, "")
    }

    /// Search the ifaddrs linked list for the first IPv4 address
    /// matching the given interface name.
    private func findIPv4Address(
        in first: UnsafeMutablePointer<ifaddrs>,
        matching interfaceName: String
    ) -> (name: String, ip: String)? {
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = current {
            let name = String(cString: ifa.pointee.ifa_name)
            if name == interfaceName,
                let addr = ifa.pointee.ifa_addr,
                addr.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](
                    repeating: 0,
                    count: Int(NI_MAXHOST)
                )
                let result = getnameinfo(
                    addr,
                    socklen_t(addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                if result == 0 {
                    return (name, String(cString: hostname))
                }
            }
            current = ifa.pointee.ifa_next
        }
        return nil
    }

    private func getDefaultInterface() -> String {
        // Use sysctl to get default route interface
        // Fallback to "en0" if unavailable
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0,
            let first = ifaddr
        else { return "en0" }
        defer { freeifaddrs(first) }

        // Find the first active en* interface with an IPv4 addr
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = current {
            let name = String(cString: ifa.pointee.ifa_name)
            let flags = Int32(ifa.pointee.ifa_flags)
            if name.hasPrefix("en"),
                flags & IFF_UP != 0,
                flags & IFF_RUNNING != 0,
                let addr = ifa.pointee.ifa_addr,
                addr.pointee.sa_family == UInt8(AF_INET) {
                return name
            }
            current = ifa.pointee.ifa_next
        }

        // Check for utun (VPN/proxy) interfaces
        current = first
        while let ifa = current {
            let name = String(cString: ifa.pointee.ifa_name)
            let flags = Int32(ifa.pointee.ifa_flags)
            if name.hasPrefix("utun"),
                flags & IFF_UP != 0,
                flags & IFF_RUNNING != 0,
                let addr = ifa.pointee.ifa_addr,
                addr.pointee.sa_family == UInt8(AF_INET) {
                return name
            }
            current = ifa.pointee.ifa_next
        }

        return "en0"
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
