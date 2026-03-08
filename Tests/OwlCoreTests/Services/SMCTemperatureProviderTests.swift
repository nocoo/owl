import Foundation
import Testing
@testable import OwlCore

// MARK: - Helper

/// Build a 32-byte SMCByteBuffer from the first few bytes; rest are zero.
private func makeBuffer(_ bytes: [UInt8]) -> SMCByteBuffer {
    var buf: [UInt8] = bytes + Array(repeating: 0, count: max(0, 32 - bytes.count))
    buf = Array(buf.prefix(32))
    return (
        buf[0], buf[1], buf[2], buf[3],
        buf[4], buf[5], buf[6], buf[7],
        buf[8], buf[9], buf[10], buf[11],
        buf[12], buf[13], buf[14], buf[15],
        buf[16], buf[17], buf[18], buf[19],
        buf[20], buf[21], buf[22], buf[23],
        buf[24], buf[25], buf[26], buf[27],
        buf[28], buf[29], buf[30], buf[31]
    )
}

// MARK: - fourCC Tests

@Suite("SMCTemperatureProvider.fourCC")
struct FourCCTests {

    @Test func sp78() {
        let code = SMCTemperatureProvider.fourCC("sp78")
        // 's'=0x73 'p'=0x70 '7'=0x37 '8'=0x38
        #expect(code == 0x73703738)
    }

    @Test func fltSpace() {
        let code = SMCTemperatureProvider.fourCC("flt ")
        // 'f'=0x66 'l'=0x6C 't'=0x74 ' '=0x20
        #expect(code == 0x666C7420)
    }

    @Test func fpe2() {
        let code = SMCTemperatureProvider.fourCC("fpe2")
        // 'f'=0x66 'p'=0x70 'e'=0x65 '2'=0x32
        #expect(code == 0x66706532)
    }

    @Test func invalidLengthReturnsZero() {
        #expect(SMCTemperatureProvider.fourCC("ab") == 0)
        #expect(SMCTemperatureProvider.fourCC("") == 0)
        #expect(SMCTemperatureProvider.fourCC("abcde") == 0)
    }
}

// MARK: - decodeTemperature Tests

@Suite("SMCTemperatureProvider.decodeTemperature")
struct DecodeTemperatureTests {

    private let sp78 = SMCTemperatureProvider.fourCC("sp78")
    private let flt = SMCTemperatureProvider.fourCC("flt ")
    private let fpe2 = SMCTemperatureProvider.fourCC("fpe2")

    // MARK: sp78 format (signed 8.8 fixed-point, big-endian)

    @Test func sp78Decode40Degrees() {
        // 40°C = 40 * 256 = 10240 = 0x2800
        let buf = makeBuffer([0x28, 0x00])
        let temp = SMCTemperatureProvider.decodeTemperature(
            bytes: buf, dataType: sp78, dataSize: 2
        )
        #expect(temp == 40.0)
    }

    @Test func sp78DecodeFractional() {
        // 40.5°C = 40.5 * 256 = 10368 = 0x2880
        let buf = makeBuffer([0x28, 0x80])
        let temp = SMCTemperatureProvider.decodeTemperature(
            bytes: buf, dataType: sp78, dataSize: 2
        )
        #expect(temp == 40.5)
    }

    @Test func sp78DecodeStaleByteProduces2Degrees() {
        // This is the exact bug scenario: if bytes.0 is 0x02
        // instead of 0x28, we get 0x0200 / 256 = 2.0°C
        let buf = makeBuffer([0x02, 0x00])
        let temp = SMCTemperatureProvider.decodeTemperature(
            bytes: buf, dataType: sp78, dataSize: 2
        )
        #expect(temp == 2.0)
    }

    @Test func sp78DecodeNegative() {
        // Negative temperature (e.g. -1°C) = -256 = 0xFF00
        let buf = makeBuffer([0xFF, 0x00])
        let temp = SMCTemperatureProvider.decodeTemperature(
            bytes: buf, dataType: sp78, dataSize: 2
        )
        #expect(temp == -1.0)
    }

    @Test func sp78InsufficientDataSize() {
        let buf = makeBuffer([0x28, 0x00])
        let temp = SMCTemperatureProvider.decodeTemperature(
            bytes: buf, dataType: sp78, dataSize: 1
        )
        #expect(temp == nil)
    }

    // MARK: flt format (IEEE 754 float, little-endian)

    @Test func fltDecode40Degrees() {
        // 40.0 as Float = 0x42200000
        // Little-endian bytes: 0x00, 0x00, 0x20, 0x42
        let buf = makeBuffer([0x00, 0x00, 0x20, 0x42])
        let temp = SMCTemperatureProvider.decodeTemperature(
            bytes: buf, dataType: flt, dataSize: 4
        )
        #expect(temp != nil)
        #expect(abs(temp! - 40.0) < 0.001)
    }

    @Test func fltDecode85Degrees() {
        // 85.0 as Float
        let bits = Float(85.0).bitPattern
        let b0 = UInt8(bits & 0xFF)
        let b1 = UInt8((bits >> 8) & 0xFF)
        let b2 = UInt8((bits >> 16) & 0xFF)
        let b3 = UInt8((bits >> 24) & 0xFF)
        let buf = makeBuffer([b0, b1, b2, b3])
        let temp = SMCTemperatureProvider.decodeTemperature(
            bytes: buf, dataType: flt, dataSize: 4
        )
        #expect(temp != nil)
        #expect(abs(temp! - 85.0) < 0.001)
    }

    @Test func fltInsufficientDataSize() {
        let buf = makeBuffer([0x00, 0x00, 0x20, 0x42])
        let temp = SMCTemperatureProvider.decodeTemperature(
            bytes: buf, dataType: flt, dataSize: 3
        )
        #expect(temp == nil)
    }

    // MARK: fpe2 format (unsigned 14.2 fixed-point, big-endian)

    @Test func fpe2Decode40Degrees() {
        // 40°C = 40 * 4 = 160 = 0x00A0
        let buf = makeBuffer([0x00, 0xA0])
        let temp = SMCTemperatureProvider.decodeTemperature(
            bytes: buf, dataType: fpe2, dataSize: 2
        )
        #expect(temp == 40.0)
    }

    @Test func fpe2DecodeFractional() {
        // 40.25°C = 40.25 * 4 = 161 = 0x00A1
        let buf = makeBuffer([0x00, 0xA1])
        let temp = SMCTemperatureProvider.decodeTemperature(
            bytes: buf, dataType: fpe2, dataSize: 2
        )
        #expect(temp == 40.25)
    }

    @Test func fpe2InsufficientDataSize() {
        let buf = makeBuffer([0x00, 0xA0])
        let temp = SMCTemperatureProvider.decodeTemperature(
            bytes: buf, dataType: fpe2, dataSize: 1
        )
        #expect(temp == nil)
    }

    // MARK: Unknown type

    @Test func unknownDataTypeReturnsNil() {
        let unknownType = SMCTemperatureProvider.fourCC("ui32")
        let buf = makeBuffer([0x00, 0x28, 0x00, 0x00])
        let temp = SMCTemperatureProvider.decodeTemperature(
            bytes: buf, dataType: unknownType, dataSize: 4
        )
        #expect(temp == nil)
    }
}

// MARK: - Validation Range Tests

@Suite("SMCTemperatureProvider.validationRange")
struct ValidationRangeTests {

    @Test func validTempMinIs5() {
        #expect(SMCTemperatureProvider.validTempMin == 5)
    }

    @Test func validTempMaxIs130() {
        #expect(SMCTemperatureProvider.validTempMax == 130)
    }

    @Test func spurious2DegreeReadingIsRejected() {
        // The bug scenario: decode returns 2.0°C which should
        // fail the validation gate (temp > 5).
        let value = 2.0
        #expect(value <= SMCTemperatureProvider.validTempMin)
    }

    @Test func normalTemperaturesAreAccepted() {
        for temp in [20.0, 40.0, 65.0, 85.0, 105.0, 129.0] {
            #expect(temp > SMCTemperatureProvider.validTempMin)
            #expect(temp < SMCTemperatureProvider.validTempMax)
        }
    }

    @Test func edgeCasesAreRejected() {
        // Exactly at boundaries
        let atMin = 5.0
        #expect(!(atMin > SMCTemperatureProvider.validTempMin))

        let atMax = 130.0
        #expect(!(atMax < SMCTemperatureProvider.validTempMax))

        // Outside boundaries
        let belowMin = 4.9
        #expect(!(belowMin > SMCTemperatureProvider.validTempMin))

        let aboveMax = 130.1
        #expect(!(aboveMax < SMCTemperatureProvider.validTempMax))
    }

    @Test func zeroDegreesRejected() {
        #expect(!(0.0 > SMCTemperatureProvider.validTempMin))
    }

    @Test func negativeDegreesRejected() {
        #expect(!(-10.0 > SMCTemperatureProvider.validTempMin))
    }
}

// MARK: - SMC Wire Format Layout Tests

@Suite("SMCParamStruct layout")
struct SMCParamStructLayoutTests {

    @Test func rawBufferIs76Bytes() {
        #expect(MemoryLayout<SMCRawBuffer>.size == 76)
        #expect(MemoryLayout<SMCRawBuffer>.stride == 76)
    }

    @Test func paramStructSizeConstantIs76() {
        #expect(SMCParamStruct.size == 76)
    }

    @Test func fieldOffsetsMatchKernelPackedLayout() {
        // These offsets must match the kernel's #pragma pack(1)
        // SMCKeyData_t layout exactly, or temperature reads
        // will be pulled from the wrong memory location.
        #expect(SMCParamStruct.offsetKey == 0)
        #expect(SMCParamStruct.offsetKiDataSize == 26)
        #expect(SMCParamStruct.offsetKiDataType == 30)
        #expect(SMCParamStruct.offsetData8 == 39)
        #expect(SMCParamStruct.offsetBytes == 44)
    }

    @Test func byteBufferIs32Bytes() {
        #expect(MemoryLayout<SMCByteBuffer>.size == 32)
    }

    @Test func setAndReadKeyRoundTrips() {
        var p = SMCParamStruct()
        let key: UInt32 = 0x54703054  // "Tp0T"
        p.setKey(key)
        // Verify by reading raw bytes at offset 0
        let readBack = withUnsafeBytes(of: p.raw) { buf in
            buf.loadUnaligned(fromByteOffset: 0, as: UInt32.self)
        }
        #expect(readBack == key)
    }

    @Test func setAndReadData8RoundTrips() {
        var p = SMCParamStruct()
        p.setData8(SMCParamStruct.kReadCommand)
        let readBack = withUnsafeBytes(of: p.raw) { buf in
            buf[SMCParamStruct.offsetData8]
        }
        #expect(readBack == 5)
    }

    @Test func setAndReadKiDataSizeRoundTrips() {
        var p = SMCParamStruct()
        let size: UInt32 = 4
        p.setKiDataSize(size)
        #expect(p.kiDataSize == size)
    }

    @Test func kiDataTypeReadsFromOffset30() {
        var p = SMCParamStruct()
        // Write a known pattern at offset 30
        withUnsafeMutableBytes(of: &p.raw) { buf in
            buf.storeBytes(
                of: UInt32(0x73703738), // "sp78"
                toByteOffset: SMCParamStruct.offsetKiDataType,
                as: UInt32.self
            )
        }
        #expect(p.kiDataType == 0x73703738)
    }

    @Test func dataBytesReadsFrom44() {
        var p = SMCParamStruct()
        // Write 0x28 at offset 44 (first byte of temperature data)
        withUnsafeMutableBytes(of: &p.raw) { buf in
            buf[44] = 0x28
            buf[45] = 0x80
        }
        let bytes = p.dataBytes
        #expect(bytes.0 == 0x28)
        #expect(bytes.1 == 0x80)
    }

    @Test func initializesToAllZeros() {
        let p = SMCParamStruct()
        withUnsafeBytes(of: p.raw) { buf in
            for i in 0..<76 {
                #expect(buf[i] == 0, "byte \(i) should be 0")
            }
        }
    }
}
