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

    /// Parse a LogEntry from ndjson Data (one line from `log stream --style ndjson`).
    public static func fromJSON(_ data: Data) throws -> LogEntry {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
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

        // Parse timestamp — use current time as fallback for performance
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

    /// Extract process name from full image path (e.g. "/usr/libexec/airportd" → "airportd").
    private static func extractProcessName(from path: String) -> String {
        guard !path.isEmpty else { return "" }
        // Fast: find last '/' and take substring after it
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

    private static func parseTimestamp(_ string: String) -> Date? {
        timestampFormatter.date(from: string)
    }
}
