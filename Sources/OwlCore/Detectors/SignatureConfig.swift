import Foundation

/// Configuration for a SignatureDetector instance.
///
/// Unlike `RateConfig` which counts raw events, `SignatureConfig` drives
/// a detector that tracks **distinct** signature diversity within a time window.
/// The detector alerts when the number of unique signatures for a group key
/// exceeds the configured thresholds.
///
/// Regex capture groups follow this convention:
/// - Group at `keyGroupIndex` = the group key (e.g. process name, bundle ID)
/// - Groups at `signatureGroupIndexes` = signature components, joined with ":"
///
/// Example for sandbox deny:
///   regex captures (process, operation, target)
///   keyGroupIndex = 1, signatureGroupIndexes = [2, 3]
///   "contactsd" is the key, "mach-lookup:com.apple.tccd.system" is the signature
public struct SignatureConfig: Sendable {
    public let id: String
    public let regex: String
    public let keyGroupIndex: Int
    public let signatureGroupIndexes: [Int]
    public let windowSeconds: Int
    public let warningDistinct: Int
    public let criticalDistinct: Int
    public let cooldownInterval: TimeInterval
    public let maxGroups: Int
    public let titleKey: L10nKey
    public let descriptionTemplateKey: L10nKey
    public let suggestionKey: L10nKey
    public let acceptsFilter: String

    /// Optional target normalizer applied to each signature component before hashing.
    /// Use this to collapse path variations (UUIDs, PIDs, temp dirs) into stable classes.
    /// When nil, raw captured strings are used as-is.
    public let normalizer: (@Sendable (String) -> String)?

    public init(
        id: String,
        regex: String,
        keyGroupIndex: Int = 1,
        signatureGroupIndexes: [Int] = [2, 3],
        windowSeconds: Int,
        warningDistinct: Int,
        criticalDistinct: Int,
        cooldownInterval: TimeInterval,
        maxGroups: Int,
        titleKey: L10nKey,
        descriptionTemplateKey: L10nKey,
        suggestionKey: L10nKey,
        acceptsFilter: String,
        normalizer: (@Sendable (String) -> String)? = nil
    ) {
        self.id = id
        self.regex = regex
        self.keyGroupIndex = keyGroupIndex
        self.signatureGroupIndexes = signatureGroupIndexes
        self.windowSeconds = windowSeconds
        self.warningDistinct = warningDistinct
        self.criticalDistinct = criticalDistinct
        self.cooldownInterval = cooldownInterval
        self.maxGroups = maxGroups
        self.titleKey = titleKey
        self.descriptionTemplateKey = descriptionTemplateKey
        self.suggestionKey = suggestionKey
        self.acceptsFilter = acceptsFilter
        self.normalizer = normalizer
    }
}
