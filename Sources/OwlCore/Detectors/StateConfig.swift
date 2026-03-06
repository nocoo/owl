import Foundation

/// Configuration for a StateDetector instance.
public struct StateConfig: Sendable {
    /// Unique detector ID (e.g. "P06").
    public let id: String

    /// Regex pattern to match "Created" events. Capture groups: (1) assertion ID, (2) type, (3) source.
    public let createdRegex: String

    /// Regex pattern to match "Released" events. Capture group: (1) assertion ID.
    public let releasedRegex: String

    /// Age in seconds after which an unpaired assertion triggers a warning.
    public let warningAge: TimeInterval

    /// Age in seconds after which an unpaired assertion triggers a critical alert.
    public let criticalAge: TimeInterval

    /// Maximum number of tracked unpaired assertions (FIFO eviction when exceeded).
    public let maxTracked: Int

    /// User-visible alert title.
    public let title: String

    /// Description template. Placeholders: `{id}`, `{type}`, `{source}`, `{age}`.
    public let descriptionTemplate: String

    /// User-visible suggestion text.
    public let suggestion: String

    /// Fast pre-filter string for `accepts()`.
    public let acceptsFilter: String

    public init(
        id: String,
        createdRegex: String,
        releasedRegex: String,
        warningAge: TimeInterval,
        criticalAge: TimeInterval,
        maxTracked: Int,
        title: String,
        descriptionTemplate: String,
        suggestion: String,
        acceptsFilter: String
    ) {
        self.id = id
        self.createdRegex = createdRegex
        self.releasedRegex = releasedRegex
        self.warningAge = warningAge
        self.criticalAge = criticalAge
        self.maxTracked = maxTracked
        self.title = title
        self.descriptionTemplate = descriptionTemplate
        self.suggestion = suggestion
        self.acceptsFilter = acceptsFilter
    }
}
