import Foundation
import IOKit

/// Reads temperatures via IOKit SMC (best effort).
/// Returns nil if SMC is not accessible.
///
/// Caches the IOKit SMC connection for the provider's lifetime
/// instead of opening/closing on every call.
public final class SMCTemperatureProvider: Sendable {

    /// Cached SMC connection. Opened lazily on first use.
    /// Access is protected by `nonisolated(unsafe)` because
    /// this provider is always held inside an actor
    /// (SystemMetricsPoller) that serializes calls.
    nonisolated(unsafe) private var cachedConnection: io_connect_t = 0
    nonisolated(unsafe) private var connectionOpen = false

    /// Last-known-good temperature per sensor key.
    /// Defense-in-depth: even with the corrected struct layout,
    /// cache valid readings so a single bad read doesn't flicker the UI.
    nonisolated(unsafe) private var lastGoodTemp: [String: Double] = [:]

    public init() {}

    deinit {
        if connectionOpen {
            IOServiceClose(cachedConnection)
        }
    }

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
        guard let conn = ensureConnection() else { return nil }
        return readFirstValid(
            connection: conn,
            keys: ["Tp0T", "TC0D", "TC0P", "TC0E"]
        )
    }

    /// Read all available temperature sensors.
    /// Returns array of (label, celsius) for sensors that responded.
    public func allTemperatures() -> [(String, Double)] {
        guard let conn = ensureConnection() else { return [] }
        var results: [(String, Double)] = []
        for (label, keys) in Self.sensorGroups {
            if let temp = readFirstValid(
                connection: conn, keys: keys
            ) {
                results.append((label, temp))
            }
        }
        return results
    }

    /// Return the cached SMC connection, opening it lazily if needed.
    private func ensureConnection() -> io_connect_t? {
        if connectionOpen { return cachedConnection }

        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC")
        )
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        let result = IOServiceOpen(
            service, mach_task_self_, 0, &connection
        )
        guard result == kIOReturnSuccess else { return nil }

        cachedConnection = connection
        connectionOpen = true
        return connection
    }

    /// Try multiple SMC keys, return first valid reading.
    /// On a valid read the value is cached per-key so that sporadic
    /// bad reads don't produce nil / flickering.
    private func readFirstValid(
        connection: io_connect_t, keys: [String]
    ) -> Double? {
        for key in keys {
            if let temp = readSMCKey(
                connection: connection, key: key
            ) {
                if temp > Self.validTempMin, temp < Self.validTempMax {
                    lastGoodTemp[key] = temp
                    return temp
                }
                // Bad read — try cached value for this key.
                if let cached = lastGoodTemp[key] {
                    return cached
                }
            }
        }
        return nil
    }

    private func readSMCKey(
        connection: io_connect_t, key: String
    ) -> Double? {
        let keyBytes = Array(key.utf8)
        guard keyBytes.count == 4 else { return nil }
        let keyCode = UInt32(keyBytes[0]) << 24
            | UInt32(keyBytes[1]) << 16
            | UInt32(keyBytes[2]) << 8
            | UInt32(keyBytes[3])

        // --- Step 1: kGetKeyInfoCommand ---
        var input = SMCParamStruct()
        var output = SMCParamStruct()
        input.setKey(keyCode)
        input.setData8(SMCParamStruct.kGetKeyInfoCommand)

        var outputSize = SMCParamStruct.size
        let infoResult = callSMC(
            connection: connection,
            input: &input.raw,
            output: &output.raw,
            outputSize: &outputSize
        )
        guard infoResult == kIOReturnSuccess else { return nil }

        let dataType = output.kiDataType
        let dataSize = output.kiDataSize

        // --- Step 2: kReadCommand (fresh structs) ---
        input = SMCParamStruct()
        output = SMCParamStruct()
        input.setKey(keyCode)
        input.setData8(SMCParamStruct.kReadCommand)
        input.setKiDataSize(dataSize)
        outputSize = SMCParamStruct.size

        let readResult = callSMC(
            connection: connection,
            input: &input.raw,
            output: &output.raw,
            outputSize: &outputSize
        )
        guard readResult == kIOReturnSuccess else { return nil }

        return Self.decodeTemperature(
            bytes: output.dataBytes,
            dataType: dataType,
            dataSize: dataSize
        )
    }

    private func callSMC(
        connection: io_connect_t,
        input: inout SMCRawBuffer,
        output: inout SMCRawBuffer,
        outputSize: inout Int
    ) -> IOReturn {
        withUnsafeMutablePointer(to: &input) { inp in
            withUnsafeMutablePointer(to: &output) { outp in
                IOConnectCallStructMethod(
                    connection,
                    2, // kSMCHandleYPCEvent
                    inp,
                    SMCParamStruct.size,
                    outp,
                    &outputSize
                )
            }
        }
    }

    /// Minimum plausible temperature in Celsius.
    static let validTempMin: Double = 5
    /// Maximum plausible temperature in Celsius.
    static let validTempMax: Double = 130

    /// Decode raw SMC bytes into a Celsius value.
    /// `internal` visibility for unit testing.
    static func decodeTemperature(
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

    /// Convert a 4-character ASCII string to a UInt32 FourCC code.
    /// `internal` visibility for unit testing.
    static func fourCC(_ str: String) -> UInt32 {
        let bytes = Array(str.utf8)
        guard bytes.count == 4 else { return 0 }
        return UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16
            | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }
}

// MARK: - SMC Wire Format

/// 32-byte buffer for decoded SMC data payload.
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

/// Raw 76-byte buffer that exactly matches the kernel's packed
/// `SMCKeyData_t` C struct (compiled with `#pragma pack(1)`).
///
/// Using a flat UInt8 tuple avoids Swift's automatic struct padding
/// which would insert extra bytes and shift field offsets, causing
/// the `bytes` payload to read from the wrong memory location.
///
/// Kernel C layout (76 bytes total):
/// ```
/// offset  0: UInt32     key           (4 bytes)
/// offset  4: SMCVers    vers          (6 bytes: 4×UInt8 + UInt16)
/// offset 10: SMCPLimit  pLimitData    (16 bytes: 2×UInt16 + 3×UInt32)
/// offset 26: SMCKeyInfo keyInfo       (9 bytes: 2×UInt32 + UInt8)
/// offset 35: UInt16     padding       (2 bytes)
/// offset 37: UInt8      result        (1 byte)
/// offset 38: UInt8      status        (1 byte)
/// offset 39: UInt8      data8         (1 byte)
/// offset 40: UInt32     data32        (4 bytes)
/// offset 44: UInt8[32]  bytes         (32 bytes)
/// ```
// swiftlint:disable:next large_tuple
typealias SMCRawBuffer = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,  //  0- 7
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,  //  8-15
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,  // 16-23
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,  // 24-31
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,  // 32-39
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,  // 40-47
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,  // 48-55
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,  // 56-63
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,  // 64-71
    UInt8, UInt8, UInt8, UInt8                                // 72-75
)

// MARK: - SMCParamStruct (safe accessor over raw buffer)

/// Type-safe wrapper around the 76-byte raw SMC buffer.
/// Provides named accessors for the fields we actually use,
/// reading/writing at the correct packed offsets.
struct SMCParamStruct: Sendable {
    static let kReadCommand: UInt8 = 5
    static let kGetKeyInfoCommand: UInt8 = 9
    static let size = MemoryLayout<SMCRawBuffer>.size  // 76

    // Field offsets matching kernel's packed C struct.
    static let offsetKey: Int = 0            // UInt32
    static let offsetKiDataSize: Int = 26    // UInt32
    static let offsetKiDataType: Int = 30    // UInt32
    static let offsetData8: Int = 39         // UInt8
    static let offsetBytes: Int = 44         // 32 × UInt8

    var raw: SMCRawBuffer

    init() {
        raw = (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0
        )
    }

    // MARK: Writers

    mutating func setKey(_ value: UInt32) {
        withUnsafeMutableBytes(of: &raw) { buf in
            buf.storeBytes(
                of: value, toByteOffset: Self.offsetKey, as: UInt32.self
            )
        }
    }

    mutating func setData8(_ value: UInt8) {
        withUnsafeMutableBytes(of: &raw) { buf in
            buf[Self.offsetData8] = value
        }
    }

    mutating func setKiDataSize(_ value: UInt32) {
        withUnsafeMutableBytes(of: &raw) { buf in
            buf.storeBytes(
                of: value, toByteOffset: Self.offsetKiDataSize, as: UInt32.self
            )
        }
    }

    // MARK: Readers

    var kiDataSize: UInt32 {
        withUnsafeBytes(of: raw) { buf in
            buf.loadUnaligned(
                fromByteOffset: Self.offsetKiDataSize, as: UInt32.self
            )
        }
    }

    var kiDataType: UInt32 {
        withUnsafeBytes(of: raw) { buf in
            buf.loadUnaligned(
                fromByteOffset: Self.offsetKiDataType, as: UInt32.self
            )
        }
    }

    /// Extract the 32-byte data payload as an SMCByteBuffer tuple.
    var dataBytes: SMCByteBuffer {
        withUnsafeBytes(of: raw) { buf in
            let o = Self.offsetBytes
            return (
                buf[o], buf[o+1], buf[o+2], buf[o+3],
                buf[o+4], buf[o+5], buf[o+6], buf[o+7],
                buf[o+8], buf[o+9], buf[o+10], buf[o+11],
                buf[o+12], buf[o+13], buf[o+14], buf[o+15],
                buf[o+16], buf[o+17], buf[o+18], buf[o+19],
                buf[o+20], buf[o+21], buf[o+22], buf[o+23],
                buf[o+24], buf[o+25], buf[o+26], buf[o+27],
                buf[o+28], buf[o+29], buf[o+30], buf[o+31]
            )
        }
    }
}
