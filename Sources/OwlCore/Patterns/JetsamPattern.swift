import Foundation

/// P10 — Jetsam Memory Kill pattern configuration.
///
/// Detects memory pressure kills by monitoring kernel Jetsam events.
/// Uses ThresholdDetector with zero debounce (any Jetsam kill is immediately
/// a warning). For critical escalation (3+ kills in 5 minutes), use a
/// companion RateDetector via `makeEscalationDetector()`.
///
/// Design: Two detectors work together:
/// - Primary (ThresholdDetector): Any single kill → immediate warning
/// - Escalation (RateDetector): 3+ kills in 5 min → critical
public enum JetsamPattern {

    public static let id = "jetsam_kill"
    public static let escalationID = "jetsam_kill_escalation"

    /// Primary detector: any single Jetsam kill triggers a warning.
    /// Uses ThresholdDetector with warningThreshold=0 and greaterThan so
    /// any positive value triggers immediately (debounce=0).
    public static func makeDetector() -> ThresholdDetector {
        ThresholdDetector(config: ThresholdConfig(
            id: id,
            regex: #"memorystatus_kill_top_process:.*pid\s+(\d+)"#,
            warningThreshold: 0,
            criticalThreshold: Double.greatestFiniteMagnitude,
            recoveryThreshold: -1,
            debounce: 0,
            comparison: .greaterThan,
            titleKey: .alertJetsamTitle,
            descriptionTemplateKey: .alertJetsamDesc("{value}"),
            suggestionKey: .alertJetsamSuggestion,
            acceptsFilter: "memorystatus_kill_top_process"
        ))
    }

    /// Escalation detector: 3+ kills in 5 minutes → critical.
    public static func makeEscalationDetector() -> RateDetector {
        RateDetector(config: RateConfig(
            id: escalationID,
            regex: #"memorystatus_kill_top_process:.*\[(.+?)\]"#,
            groupBy: .global,
            windowSeconds: 300,
            warningRate: Int.max,
            criticalRate: 3,
            cooldownInterval: 60,
            maxGroups: 1,
            titleKey: .alertJetsamEscTitle,
            descriptionTemplateKey: .alertJetsamEscDesc("{count}"),
            suggestionKey: .alertJetsamEscSuggestion,
            acceptsFilter: "memorystatus_kill_top_process"
        ))
    }
}
