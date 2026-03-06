import Foundation

/// Configuration for a ThresholdDetector instance.
public struct ThresholdConfig: Sendable {
    /// Unique detector ID (e.g. "P01").
    public let id: String

    /// Regex pattern string to extract a numeric value from eventMessage.
    /// Must contain exactly one capture group matching a number.
    public let regex: String

    /// Value at or beyond which a warning is triggered (direction depends on `comparison`).
    public let warningThreshold: Double

    /// Value at or beyond which a critical alert is triggered.
    public let criticalThreshold: Double

    /// Value at or beyond which recovery is confirmed (hysteresis band).
    public let recoveryThreshold: Double

    /// Debounce duration in seconds. Value must remain in warning zone for this long before alerting.
    public let debounce: TimeInterval

    /// Comparison direction for threshold evaluation.
    public let comparison: Comparison

    /// User-visible alert title.
    public let title: String

    /// Description template. Use `{value}` as placeholder for the extracted value.
    public let descriptionTemplate: String

    /// User-visible suggestion text.
    public let suggestion: String

    /// Fast pre-filter string for `accepts()`. Uses `String.contains()`.
    public let acceptsFilter: String

    public init(
        id: String,
        regex: String,
        warningThreshold: Double,
        criticalThreshold: Double,
        recoveryThreshold: Double,
        debounce: TimeInterval,
        comparison: Comparison,
        title: String,
        descriptionTemplate: String,
        suggestion: String,
        acceptsFilter: String
    ) {
        self.id = id
        self.regex = regex
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
        self.recoveryThreshold = recoveryThreshold
        self.debounce = debounce
        self.comparison = comparison
        self.title = title
        self.descriptionTemplate = descriptionTemplate
        self.suggestion = suggestion
        self.acceptsFilter = acceptsFilter
    }
}
