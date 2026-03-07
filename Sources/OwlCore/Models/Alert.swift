import Foundation

/// An alert produced by a pattern detector when an anomaly is detected.
public struct Alert: Sendable, Equatable {
    /// The ID of the detector that produced this alert (e.g. "P01").
    public let detectorID: String

    /// Severity level of this alert.
    public let severity: Severity

    /// User-visible title (short, descriptive).
    public let title: String

    /// User-visible description with details about the anomaly.
    public let description: String

    /// Suggested action the user can take to resolve the issue.
    public let suggestion: String

    /// Timestamp when this alert was produced.
    public let timestamp: Date

    /// Time-to-live in seconds. Alert expires after this duration.
    public let ttl: TimeInterval

    public init(
        detectorID: String,
        severity: Severity,
        title: String,
        description: String,
        suggestion: String,
        timestamp: Date,
        ttl: TimeInterval? = nil
    ) {
        self.detectorID = detectorID
        self.severity = severity
        self.title = title
        self.description = description
        self.suggestion = suggestion
        self.timestamp = timestamp
        self.ttl = ttl ?? Self.defaultTTL(for: severity)
    }

    /// Formatted text for copying to clipboard.
    public var clipboardText: String {
        var lines = [
            "[\(severity)] \(title)",
            description
        ]
        if !suggestion.isEmpty {
            lines.append(L10n.tr(.clipboardSuggestion(suggestion)))
        }
        lines.append(
            L10n.tr(.clipboardDetector(
                detectorID,
                Self.clipboardFormatter.string(from: timestamp)
            ))
        )
        return lines.joined(separator: "\n")
    }

    private static let clipboardFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        fmt.timeZone = .current
        return fmt
    }()

    /// Check whether this alert has expired at a given point in time.
    public func isExpired(at date: Date) -> Bool {
        date.timeIntervalSince(timestamp) > ttl
    }

    /// Default TTL values per severity level (from design doc).
    private static func defaultTTL(for severity: Severity) -> TimeInterval {
        switch severity {
        case .info:
            60
        case .warning:
            300
        case .critical:
            600
        case .normal:
            60
        }
    }
}
