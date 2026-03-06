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

    /// User-visible alert title.
    public let title: String

    /// Description template. Placeholders: `{key}`, `{count}`, `{window}`.
    public let descriptionTemplate: String

    /// User-visible suggestion text.
    public let suggestion: String

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
        title: String,
        descriptionTemplate: String,
        suggestion: String,
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
        self.title = title
        self.descriptionTemplate = descriptionTemplate
        self.suggestion = suggestion
        self.acceptsFilter = acceptsFilter
    }
}
