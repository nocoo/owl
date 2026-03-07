import Foundation

/// Grouping strategy for RateDetector event counting.
public enum GroupBy: Sendable {
    /// Group by regex capture group (e.g. process name, bundle ID).
    case captureGroup
    /// No grouping — count all matching events globally.
    case global
}

/// Configuration for a RateDetector instance.
public struct RateConfig: Sendable {
    /// Unique detector ID (e.g. "P02").
    public let id: String

    /// Regex pattern string to match and optionally extract a group key.
    public let regex: String

    /// How to group events for counting.
    public let groupBy: GroupBy

    /// Sliding window size in seconds.
    public let windowSeconds: Int

    /// Event count within the window that triggers a warning.
    public let warningRate: Int

    /// Event count within the window that triggers a critical alert.
    public let criticalRate: Int

    /// Cooldown interval after an alert before another can fire for the same key.
    public let cooldownInterval: TimeInterval

    /// Maximum number of tracked groups (LRU eviction when exceeded).
    public let maxGroups: Int

    /// User-visible alert title key, resolved at alert emission time.
    public let titleKey: L10nKey

    /// Description template key. Placeholders: `{key}`, `{count}`, `{window}`.
    public let descriptionTemplateKey: L10nKey

    /// User-visible suggestion text key.
    public let suggestionKey: L10nKey

    /// Fast pre-filter string for `accepts()`.
    public let acceptsFilter: String

    public init(
        id: String,
        regex: String,
        groupBy: GroupBy,
        windowSeconds: Int,
        warningRate: Int,
        criticalRate: Int,
        cooldownInterval: TimeInterval,
        maxGroups: Int,
        titleKey: L10nKey,
        descriptionTemplateKey: L10nKey,
        suggestionKey: L10nKey,
        acceptsFilter: String
    ) {
        self.id = id
        self.regex = regex
        self.groupBy = groupBy
        self.windowSeconds = windowSeconds
        self.warningRate = warningRate
        self.criticalRate = criticalRate
        self.cooldownInterval = cooldownInterval
        self.maxGroups = maxGroups
        self.titleKey = titleKey
        self.descriptionTemplateKey = descriptionTemplateKey
        self.suggestionKey = suggestionKey
        self.acceptsFilter = acceptsFilter
    }
}
