import Foundation

/// Error types for LogEntry JSON parsing.
public enum LogEntryParseError: Error, Sendable {
    case missingField(String)
    case invalidJSON
}

/// A single log entry parsed from macOS unified log stream (ndjson format).
public struct LogEntry: Sendable {
    public let timestamp: Date
    public let process: String
    public let processID: Int
    public let subsystem: String
    public let category: String
    public let messageType: String
    public let eventMessage: String

    public init(
        timestamp: Date,
        process: String,
        processID: Int,
        subsystem: String,
        category: String,
        messageType: String,
        eventMessage: String
    ) {
        self.timestamp = timestamp
        self.process = process
        self.processID = processID
        self.subsystem = subsystem
        self.category = category
        self.messageType = messageType
        self.eventMessage = eventMessage
    }

    /// Parse a LogEntry from ndjson Data using JSONSerialization.
    /// Used by tests that construct JSON via dictionaries.
    /// For hot-path parsing of raw log lines, use `fromLine()` instead.
    public static func fromJSON(_ data: Data) throws -> LogEntry {
        guard let dict = try JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any] else {
            throw LogEntryParseError.invalidJSON
        }

        guard let eventMessage = dict["eventMessage"] as? String else {
            throw LogEntryParseError.missingField("eventMessage")
        }

        let processImagePath = dict["processImagePath"] as? String ?? ""
        let process = extractProcessName(from: processImagePath)
        let processID = dict["processID"] as? Int ?? 0
        let subsystem = dict["subsystem"] as? String ?? ""
        let category = dict["category"] as? String ?? ""
        let messageType = dict["messageType"] as? String ?? "Default"

        let timestamp: Date
        if let ts = dict["timestamp"] as? String {
            timestamp = parseTimestamp(ts) ?? Date()
        } else {
            timestamp = Date()
        }

        return LogEntry(
            timestamp: timestamp,
            process: process,
            processID: processID,
            subsystem: subsystem,
            category: category,
            messageType: messageType,
            eventMessage: eventMessage
        )
    }

    /// Parse a LogEntry from a raw ndjson line string using fast
    /// string extraction (no JSONSerialization). This is the hot-path
    /// parser called ~277 times/sec from LogStreamReader.
    ///
    /// Returns `nil` for empty/whitespace-only lines.
    /// Throws for missing required `eventMessage` field.
    public static func fromLine(_ line: String) throws -> LogEntry? {
        let trimmed = line.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return nil }

        // Must start with '{' to be valid ndjson
        guard trimmed.hasPrefix("{") else {
            throw LogEntryParseError.invalidJSON
        }

        return try fastParse(trimmed)
    }

    // MARK: - Fast string-based parser

    /// Extract fields directly from raw JSON text without
    /// building a full dictionary. Only reads the 7 fields we need.
    /// ~5-10x faster than JSONSerialization for our use case.
    private static func fastParse(
        _ json: String
    ) throws -> LogEntry {
        guard let msg = extractStringValue(
            from: json, key: "eventMessage"
        ) else {
            throw LogEntryParseError.missingField("eventMessage")
        }

        let path = extractStringValue(
            from: json, key: "processImagePath"
        ) ?? ""
        let process = extractProcessName(from: path)

        let pid = extractIntValue(
            from: json, key: "processID"
        ) ?? 0

        let subsystem = extractStringValue(
            from: json, key: "subsystem"
        ) ?? ""
        let category = extractStringValue(
            from: json, key: "category"
        ) ?? ""
        let messageType = extractStringValue(
            from: json, key: "messageType"
        ) ?? "Default"

        let timestamp: Date
        if let ts = extractStringValue(
            from: json, key: "timestamp"
        ) {
            timestamp = parseTimestamp(ts) ?? Date()
        } else {
            timestamp = Date()
        }

        return LogEntry(
            timestamp: timestamp,
            process: process,
            processID: pid,
            subsystem: subsystem,
            category: category,
            messageType: messageType,
            eventMessage: msg
        )
    }

    /// Extract a JSON string value for the given key.
    /// Searches for `"key":"` and reads until the closing
    /// unescaped `"`. Handles `\"` escapes inside values and
    /// `\/` path separators.
    ///
    /// Returns `nil` if the key is not found.
    static func extractStringValue(
        from json: String, key: String
    ) -> String? {
        // Build the search needle: "key":"
        let needle = "\"\(key)\":\""
        guard let needleRange = json.range(of: needle) else {
            return nil
        }

        // Value starts right after the needle
        let valueStart = needleRange.upperBound
        return readJSONStringValue(from: json, startingAt: valueStart)
    }

    /// Read a JSON string value starting at the given index
    /// (just after the opening `"`). Handles escape sequences.
    private static func readJSONStringValue(
        from json: String,
        startingAt start: String.Index
    ) -> String? {
        var result: [Character] = []
        var index = start
        let end = json.endIndex
        var escaped = false

        while index < end {
            let char = json[index]

            if escaped {
                result.append(unescapeChar(char))
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                return String(result)
            } else {
                result.append(char)
            }

            index = json.index(after: index)
        }

        return nil // unterminated string
    }

    /// Convert a JSON escape sequence character to its actual value.
    private static func unescapeChar(_ char: Character) -> Character {
        switch char {
        case "\"": return "\""
        case "\\": return "\\"
        case "/": return "/"
        case "n": return "\n"
        case "t": return "\t"
        case "r": return "\r"
        default: return char
        }
    }

    /// Extract a JSON integer value for the given key.
    /// Searches for `"key":` followed by digits (with optional
    /// leading minus sign).
    static func extractIntValue(
        from json: String, key: String
    ) -> Int? {
        let needle = "\"\(key)\":"
        guard let needleRange = json.range(of: needle) else {
            return nil
        }

        var index = needleRange.upperBound
        let end = json.endIndex

        // Skip whitespace
        while index < end, json[index] == " " {
            index = json.index(after: index)
        }

        // If it's a quoted string (not a number), return nil
        guard index < end, json[index] != "\"" else {
            return nil
        }

        // Collect digits (and optional leading minus)
        var numStr: [Character] = []
        if index < end, json[index] == "-" {
            numStr.append("-")
            index = json.index(after: index)
        }
        while index < end {
            let char = json[index]
            guard char.isASCII, char.isNumber else { break }
            numStr.append(char)
            index = json.index(after: index)
        }

        guard !numStr.isEmpty else { return nil }
        return Int(String(numStr))
    }

    // MARK: - Shared helpers

    /// Extract process name from full image path.
    /// e.g. "/usr/libexec/airportd" → "airportd",
    ///      "/kernel" → "kernel"
    private static func extractProcessName(
        from path: String
    ) -> String {
        guard !path.isEmpty else { return "" }
        if let lastSlash = path.lastIndex(of: "/") {
            return String(path[path.index(after: lastSlash)...])
        }
        return path
    }

    /// Parse timestamp string from log stream.
    /// Format: "2026-03-06 08:30:44.123456+0800"
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSxxxx"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func parseTimestamp(
        _ string: String
    ) -> Date? {
        timestampFormatter.date(from: string)
    }
}
