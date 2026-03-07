import Foundation
import IOKit

/// Reads temperatures via IOKit SMC (best effort).
/// Returns nil if SMC is not accessible.
public struct SMCTemperatureProvider: Sendable {
    public init() {}

    /// Known sensor groups: (label, candidate SMC keys).
    /// First valid key wins per group.
    private static let sensorGroups: [(String, [String])] = [
        ("CPU", ["Tp0T", "TC0D", "TC0P", "TC0E"]),
        ("GPU", ["Tg05", "TG0D", "TG0P"]),
        ("SSD", ["TH0x", "TH0a", "TH0b"]),
    ]

    /// Attempt to read CPU die temperature.
    /// Returns Celsius value or nil if unavailable.
    public func cpuTemperature() -> Double? {
        withSMCConnection { conn in
            readFirstValid(
                connection: conn,
                keys: ["Tp0T", "TC0D", "TC0P", "TC0E"]
            )
        } ?? nil
    }

    /// Read all available temperature sensors.
    /// Returns array of (label, celsius) for sensors that responded.
    public func allTemperatures() -> [(String, Double)] {
        withSMCConnection { conn in
            var results: [(String, Double)] = []
            for (label, keys) in Self.sensorGroups {
                if let temp = readFirstValid(
                    connection: conn, keys: keys
                ) {
                    results.append((label, temp))
                }
            }
            return results
        } ?? []
    }

    /// Open SMC connection, run closure, close.
    private func withSMCConnection<T>(
        _ body: (io_connect_t) -> T
    ) -> T? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC")
        )
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        let openResult = IOServiceOpen(
            service, mach_task_self_, 0, &connection
        )
        guard openResult == kIOReturnSuccess else {
            return nil
        }
        defer { IOServiceClose(connection) }
        return body(connection)
    }

    /// Try multiple SMC keys, return first valid reading.
    private func readFirstValid(
        connection: io_connect_t, keys: [String]
    ) -> Double? {
        for key in keys {
            if let temp = readSMCKey(
                connection: connection, key: key
            ), temp > 0, temp < 150 {
                return temp
            }
        }
        return nil
    }

    private func readSMCKey(
        connection: io_connect_t, key: String
    ) -> Double? {
        var inputStruct = SMCKeyData()
        var outputStruct = SMCKeyData()

        let keyBytes = Array(key.utf8)
        guard keyBytes.count == 4 else { return nil }
        inputStruct.key = UInt32(keyBytes[0]) << 24
            | UInt32(keyBytes[1]) << 16
            | UInt32(keyBytes[2]) << 8
            | UInt32(keyBytes[3])
        inputStruct.data8 = SMCKeyData.kReadCommand

        var outputSize = MemoryLayout<SMCKeyData>.stride

        // Get key info to learn the data type
        inputStruct.data8 = SMCKeyData.kGetKeyInfoCommand
        let infoResult = callSMC(
            connection: connection,
            input: &inputStruct,
            output: &outputStruct,
            outputSize: &outputSize
        )
        guard infoResult == kIOReturnSuccess else {
            return nil
        }

        let dataType = outputStruct.keyInfo.dataType
        let dataSize = outputStruct.keyInfo.dataSize

        // Now read the value
        inputStruct.data8 = SMCKeyData.kReadCommand
        inputStruct.keyInfo.dataSize = dataSize
        outputSize = MemoryLayout<SMCKeyData>.stride

        let readResult = callSMC(
            connection: connection,
            input: &inputStruct,
            output: &outputStruct,
            outputSize: &outputSize
        )
        guard readResult == kIOReturnSuccess else {
            return nil
        }

        return decodeTemperature(
            bytes: outputStruct.bytes,
            dataType: dataType,
            dataSize: dataSize
        )
    }

    private func callSMC(
        connection: io_connect_t,
        input: inout SMCKeyData,
        output: inout SMCKeyData,
        outputSize: inout Int
    ) -> IOReturn {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        return withUnsafeMutablePointer(to: &input) { inp in
            withUnsafeMutablePointer(to: &output) { outp in
                IOConnectCallStructMethod(
                    connection,
                    2, // kSMCHandleYPCEvent
                    inp,
                    inputSize,
                    outp,
                    &outputSize
                )
            }
        }
    }

    private func decodeTemperature(
        bytes: SMCByteBuffer,
        dataType: UInt32,
        dataSize: UInt32
    ) -> Double? {
        let sp78 = fourCC("sp78")
        let flt = fourCC("flt ")

        if dataType == sp78, dataSize >= 2 {
            let raw = Int16(bytes.0) << 8 | Int16(bytes.1)
            return Double(raw) / 256.0
        }

        if dataType == flt, dataSize >= 4 {
            // Apple Silicon returns flt as little-endian
            let bits = UInt32(bytes.0)
                | UInt32(bytes.1) << 8
                | UInt32(bytes.2) << 16
                | UInt32(bytes.3) << 24
            return Double(Float(bitPattern: bits))
        }

        let fpe2 = fourCC("fpe2")
        if dataType == fpe2, dataSize >= 2 {
            let raw = UInt16(bytes.0) << 8 | UInt16(bytes.1)
            return Double(raw) / 4.0
        }

        return nil
    }

    private func fourCC(_ str: String) -> UInt32 {
        let bytes = Array(str.utf8)
        guard bytes.count == 4 else { return 0 }
        return UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16
            | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }
}

// MARK: - SMC Type Aliases

// 32-byte buffer for SMC data.
// swiftlint:disable:next large_tuple
typealias SMCByteBuffer = (
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8
)

// MARK: - SMC Data Structures

/// Raw SMC key data structure for IOKit calls.
struct SMCKeyData: Sendable {
    static let kReadCommand: UInt8 = 5
    static let kGetKeyInfoCommand: UInt8 = 9

    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCByteBuffer = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

struct SMCVersion: Sendable {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

struct SMCPLimitData: Sendable {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

struct SMCKeyInfoData: Sendable {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}
