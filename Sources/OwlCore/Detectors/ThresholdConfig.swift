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

    /// User-visible alert title key, resolved at alert emission time.
    public let titleKey: L10nKey

    /// Description template key. Use `{value}` as placeholder for the extracted value.
    public let descriptionTemplateKey: L10nKey

    /// User-visible suggestion text key.
    public let suggestionKey: L10nKey

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
        titleKey: L10nKey,
        descriptionTemplateKey: L10nKey,
        suggestionKey: L10nKey,
        acceptsFilter: String
    ) {
        self.id = id
        self.regex = regex
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
        self.recoveryThreshold = recoveryThreshold
        self.debounce = debounce
        self.comparison = comparison
        self.titleKey = titleKey
        self.descriptionTemplateKey = descriptionTemplateKey
        self.suggestionKey = suggestionKey
        self.acceptsFilter = acceptsFilter
    }
}
