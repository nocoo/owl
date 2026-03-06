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
