import Foundation
import Testing
@testable import OwlCore

@Suite("LogEntry")
struct LogEntryTests {

    // MARK: - Initialization

    @Test func initializesWithAllFields() {
        let now = Date()
        let entry = LogEntry(
            timestamp: now,
            process: "kernel",
            processID: 0,
            subsystem: "com.apple.kernel",
            category: "default",
            messageType: "Default",
            eventMessage: "test message"
        )

        #expect(entry.timestamp == now)
        #expect(entry.process == "kernel")
        #expect(entry.processID == 0)
        #expect(entry.subsystem == "com.apple.kernel")
        #expect(entry.category == "default")
        #expect(entry.messageType == "Default")
        #expect(entry.eventMessage == "test message")
    }

    // MARK: - JSON parsing (ndjson format from log stream)

    @Test func parsesFromNdjsonDictionary() throws {
        let json: [String: Any] = [
            "timestamp": "2026-03-06 08:30:44.123456+0800",
            "eventMessage": "setDetailedThermalPowerBudget: current power budget: 4500",
            "processID": 0,
            "processImagePath": "/kernel",
            "subsystem": "com.apple.kernel",
            "category": "default",
            "messageType": "Default"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let entry = try LogEntry.fromJSON(data)

        #expect(entry.process == "kernel")
        #expect(entry.processID == 0)
        #expect(entry.subsystem == "com.apple.kernel")
        #expect(entry.category == "default")
        #expect(entry.eventMessage == "setDetailedThermalPowerBudget: current power budget: 4500")
    }

    @Test func parsesProcessNameFromImagePath() throws {
        let json: [String: Any] = [
            "timestamp": "2026-03-06 08:30:44.123456+0800",
            "eventMessage": "test",
            "processID": 123,
            "processImagePath": "/usr/libexec/airportd",
            "subsystem": "",
            "category": "",
            "messageType": "Default"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let entry = try LogEntry.fromJSON(data)

        #expect(entry.process == "airportd")
    }

    @Test func handlesEmptyProcessImagePath() throws {
        let json: [String: Any] = [
            "timestamp": "2026-03-06 08:30:44.123456+0800",
            "eventMessage": "test",
            "processID": 0,
            "processImagePath": "",
            "subsystem": "",
            "category": "",
            "messageType": "Default"
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let entry = try LogEntry.fromJSON(data)

        #expect(entry.process.isEmpty)
    }

    @Test func throwsOnMissingEventMessage() {
        let json: [String: Any] = [
            "timestamp": "2026-03-06 08:30:44.123456+0800",
            "processID": 0
        ]

        #expect(throws: LogEntryParseError.self) {
            let data = try JSONSerialization.data(withJSONObject: json)
            _ = try LogEntry.fromJSON(data)
        }
    }

    @Test func throwsOnInvalidJSON() {
        let garbage = Data("not json".utf8)
        #expect(throws: (any Error).self) {
            _ = try LogEntry.fromJSON(garbage)
        }
    }

    // MARK: - fromLine() parsing

    @Test func fromLineReturnsNilForEmptyString() throws {
        #expect(try LogEntry.fromLine("") == nil)
    }

    @Test func fromLineReturnsNilForWhitespace() throws {
        #expect(try LogEntry.fromLine("   \n  ") == nil)
    }

    @Test func fromLineParsesValidJSON() throws {
        // swiftlint:disable:next line_length
        let line = #"{"timestamp":"2026-03-06 08:30:44.123456+0800","eventMessage":"test msg","processID":42,"processImagePath":"/usr/bin/foo","subsystem":"","category":"","messageType":"Default"}"#
        let entry = try LogEntry.fromLine(line)
        #expect(entry != nil)
        #expect(entry?.process == "foo")
        #expect(entry?.eventMessage == "test msg")
    }

    @Test func fromLineThrowsOnMalformedJSON() {
        #expect(throws: (any Error).self) {
            _ = try LogEntry.fromLine("{incomplete json")
        }
    }

    @Test func fromLineHandlesTrailingNewline() throws {
        // swiftlint:disable:next line_length
        let line = #"{"timestamp":"2026-03-06 08:30:44.123456+0800","eventMessage":"hello","processID":0,"processImagePath":"","subsystem":"","category":"","messageType":"Default"}"# + "\n"
        let entry = try LogEntry.fromLine(line)
        #expect(entry != nil)
        #expect(entry?.eventMessage == "hello")
    }

    // MARK: - fromLine() fast parser: edge cases

    @Test func fromLineHandlesEscapedQuotesInMessage() throws {
        // swiftlint:disable:next line_length
        let line = #"{"eventMessage":"QUIT: pid = 85412, name = \"com.example.app\"","processID":100,"processImagePath":"/usr/sbin/launchservicesd","subsystem":"","category":"","messageType":"Default","timestamp":"2026-03-06 08:30:44.123456+0800"}"#
        let entry = try LogEntry.fromLine(line)
        #expect(entry != nil)
        #expect(entry?.eventMessage == #"QUIT: pid = 85412, name = "com.example.app""#)
        #expect(entry?.process == "launchservicesd")
        #expect(entry?.processID == 100)
    }

    @Test func fromLineHandlesEscapedSlashesInPath() throws {
        // Real ndjson uses \/ for path separators
        // swiftlint:disable:next line_length
        let line = #"{"eventMessage":"test","processID":0,"processImagePath":"\/System\/Library\/Extensions\/IOSurface.kext","subsystem":"","category":"","messageType":"Default","timestamp":"2026-03-06 08:30:44.123456+0800"}"#
        let entry = try LogEntry.fromLine(line)
        #expect(entry != nil)
        #expect(entry?.process == "IOSurface.kext")
    }

    @Test func fromLineHandlesMissingOptionalFields() throws {
        // Only eventMessage is required; all others default
        let line = #"{"eventMessage":"minimal entry"}"#
        let entry = try LogEntry.fromLine(line)
        #expect(entry != nil)
        #expect(entry?.eventMessage == "minimal entry")
        #expect(entry?.process.isEmpty == true)
        #expect(entry?.processID == 0)
        #expect(entry?.subsystem.isEmpty == true)
        #expect(entry?.category.isEmpty == true)
        #expect(entry?.messageType == "Default")
    }

    @Test func fromLineThrowsOnNonJSONContent() {
        #expect(throws: LogEntryParseError.self) {
            _ = try LogEntry.fromLine("Filtering the log data")
        }
    }

    @Test func fromLineParsesRealLogStreamOutput() throws {
        // Realistic ndjson line with many extra fields (backtrace, UUIDs, etc.)
        // swiftlint:disable:next line_length
        let line = #"{"timezoneName":"","messageType":"Error","eventType":"logEvent","source":null,"formatString":"SID: 0x%X","userID":0,"activityIdentifier":0,"subsystem":"com.apple.iokit","category":"power","threadID":4939,"senderImageUUID":"C332CE63","processImagePath":"\/kernel","senderImagePath":"\/System\/Library\/Extensions\/IOSurface.kext\/Contents\/MacOS\/IOSurface","timestamp":"2026-03-06 13:30:09.202323+0800","machTimestamp":432123150336,"eventMessage":"DarkWake from Normal Sleep [CDNPB] due to EC.LidOpen","processImageUUID":"5E5C46C9","traceID":103147935109124,"processID":0,"senderProgramCounter":120448,"parentActivityIdentifier":0}"#
        let entry = try LogEntry.fromLine(line)
        #expect(entry != nil)
        #expect(entry?.process == "kernel")
        #expect(entry?.processID == 0)
        #expect(entry?.subsystem == "com.apple.iokit")
        #expect(entry?.category == "power")
        #expect(entry?.messageType == "Error")
        #expect(
            entry?.eventMessage ==
            "DarkWake from Normal Sleep [CDNPB] due to EC.LidOpen"
        )
    }

    @Test func fromLineParsesNegativeProcessID() throws {
        // swiftlint:disable:next line_length
        let line = #"{"eventMessage":"test","processID":-1,"processImagePath":"","subsystem":"","category":"","messageType":"Default"}"#
        let entry = try LogEntry.fromLine(line)
        #expect(entry?.processID == -1)
    }

    // MARK: - extractStringValue unit tests

    @Test func extractStringValueFindsSimpleValue() {
        let json = #"{"key":"value","other":"stuff"}"#
        let result = LogEntry.extractStringValue(
            from: json, key: "key"
        )
        #expect(result == "value")
    }

    @Test func extractStringValueHandlesEscapedQuotes() {
        let json = #"{"msg":"hello \"world\""}"#
        let result = LogEntry.extractStringValue(
            from: json, key: "msg"
        )
        #expect(result == #"hello "world""#)
    }

    @Test func extractStringValueHandlesEscapedBackslash() {
        let json = #"{"path":"C:\\Users\\test"}"#
        let result = LogEntry.extractStringValue(
            from: json, key: "path"
        )
        #expect(result == #"C:\Users\test"#)
    }

    @Test func extractStringValueReturnsNilForMissingKey() {
        let json = #"{"key":"value"}"#
        let result = LogEntry.extractStringValue(
            from: json, key: "missing"
        )
        #expect(result == nil)
    }

    @Test func extractStringValueHandlesEmptyString() {
        let json = #"{"key":""}"#
        let result = LogEntry.extractStringValue(
            from: json, key: "key"
        )
        #expect(result?.isEmpty == true)
    }

    // MARK: - extractIntValue unit tests

    @Test func extractIntValueFindsNumber() {
        let json = #"{"pid":42,"name":"test"}"#
        let result = LogEntry.extractIntValue(
            from: json, key: "pid"
        )
        #expect(result == 42)
    }

    @Test func extractIntValueFindsZero() {
        let json = #"{"pid":0}"#
        let result = LogEntry.extractIntValue(
            from: json, key: "pid"
        )
        #expect(result == 0)
    }

    @Test func extractIntValueReturnsNilForMissingKey() {
        let json = #"{"key":"value"}"#
        let result = LogEntry.extractIntValue(
            from: json, key: "missing"
        )
        #expect(result == nil)
    }

    @Test func extractIntValueReturnsNilForStringValue() {
        let json = #"{"pid":"not_a_number"}"#
        let result = LogEntry.extractIntValue(
            from: json, key: "pid"
        )
        #expect(result == nil)
    }

    // MARK: - Sendable conformance (compile-time check)

    @Test func isSendable() async {
        let entry = LogEntry(
            timestamp: Date(),
            process: "kernel",
            processID: 0,
            subsystem: "",
            category: "",
            messageType: "Default",
            eventMessage: "test"
        )

        // Passing across isolation boundary verifies Sendable
        let task = Task { entry.process }
        let result = await task.value
        #expect(result == "kernel")
    }
}
