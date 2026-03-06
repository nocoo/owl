import Foundation
import IOKit

/// Reads CPU temperature via IOKit SMC (best effort).
/// Returns nil if SMC is not accessible.
public struct SMCTemperatureProvider: Sendable {
    public init() {}

    /// Attempt to read CPU die temperature.
    /// Returns Celsius value or nil if unavailable.
    public func cpuTemperature() -> Double? {
        // Try AppleSMC service
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

        // SMC key "TC0P" = CPU proximity temperature
        // key "TC0D" = CPU die temperature (preferred)
        for key in ["TC0D", "TC0P", "TC0E"] {
            if let temp = readSMCKey(
                connection: connection, key: key
            ), temp > 0, temp < 150 {
                return temp
            }
        }

        return nil
    }

    // swiftlint:disable:next function_body_length
    private func readSMCKey(
        connection: io_connect_t, key: String
    ) -> Double? {
        // SMC structures
        var inputStruct = SMCKeyData()
        var outputStruct = SMCKeyData()

        // Convert key string to UInt32
        let keyBytes = Array(key.utf8)
        guard keyBytes.count == 4 else { return nil }
        inputStruct.key = UInt32(keyBytes[0]) << 24
            | UInt32(keyBytes[1]) << 16
            | UInt32(keyBytes[2]) << 8
            | UInt32(keyBytes[3])
        inputStruct.data8 = SMCKeyData.kReadCommand

        var outputSize = MemoryLayout<SMCKeyData>.stride

        // First: get key info to learn the data type
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
        bytes: (
            UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8
        ),
        dataType: UInt32,
        dataSize: UInt32
    ) -> Double? {
        // "sp78" type: signed 7.8 fixed point
        let sp78 = fourCC("sp78")
        // "flt " type: 32-bit float
        let flt = fourCC("flt ")

        if dataType == sp78, dataSize >= 2 {
            let raw = Int16(bytes.0) << 8 | Int16(bytes.1)
            return Double(raw) / 256.0
        }

        if dataType == flt, dataSize >= 4 {
            let bits = UInt32(bytes.0) << 24
                | UInt32(bytes.1) << 16
                | UInt32(bytes.2) << 8
                | UInt32(bytes.3)
            return Double(Float(bitPattern: bits))
        }

        // "fpe2": unsigned 14.2 fixed point
        let fpe2 = fourCC("fpe2")
        if dataType == fpe2, dataSize >= 2 {
            let raw = UInt16(bytes.0) << 8 | UInt16(bytes.1)
            return Double(raw) / 4.0
        }

        return nil
    }

    private func fourCC(_ str: String) -> UInt32 {
        let b = Array(str.utf8)
        guard b.count == 4 else { return 0 }
        return UInt32(b[0]) << 24 | UInt32(b[1]) << 16
            | UInt32(b[2]) << 8 | UInt32(b[3])
    }
}

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
    var bytes: (
        UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8
    ) = (
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
