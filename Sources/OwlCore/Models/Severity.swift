import Foundation

/// Alert severity levels, ordered from least to most severe.
public enum Severity: Int, Comparable, Codable, Sendable {
    case normal = 0
    case info = 1
    case warning = 2
    case critical = 3

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
