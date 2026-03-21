import Foundation

/// Configuration for a metrics threshold detector.
///
/// Defines warning/critical thresholds, recovery hysteresis, and the
/// sustained duration required before emitting an alert.
public struct MetricsThresholdConfig: Sendable {
    /// Detector identifier.
    public let id: String

    /// Value above this triggers the warning tracking window.
    public let warningThreshold: Double

    /// Value above this escalates to critical (must be > warningThreshold).
    public let criticalThreshold: Double

    /// Value at or below this is considered recovered (hysteresis).
    public let recoveryThreshold: Double

    /// Seconds the value must stay above threshold before emitting.
    public let sustainedDuration: TimeInterval

    /// Title L10n key factory.
    public let titleKey: L10nKey

    /// Description L10n key factory (receives formatted value string).
    public let descriptionKey: @Sendable (String) -> L10nKey

    /// Suggestion L10n key.
    public let suggestionKey: L10nKey

    /// How to format the current value for the alert description.
    public let formatValue: @Sendable (Double) -> String

    public init(
        id: String,
        warningThreshold: Double,
        criticalThreshold: Double,
        recoveryThreshold: Double,
        sustainedDuration: TimeInterval,
        titleKey: L10nKey,
        descriptionKey: @escaping @Sendable (String) -> L10nKey,
        suggestionKey: L10nKey,
        formatValue: @escaping @Sendable (Double) -> String = {
            String(format: "%.1f", $0)
        }
    ) {
        self.id = id
        self.warningThreshold = warningThreshold
        self.criticalThreshold = criticalThreshold
        self.recoveryThreshold = recoveryThreshold
        self.sustainedDuration = sustainedDuration
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.suggestionKey = suggestionKey
        self.formatValue = formatValue
    }
}

/// Generic metrics threshold detector with sustained duration and hysteresis.
///
/// State machine:
/// ```
/// normal ──[value>warning]──→ elevated(since) ──[sustained≥duration]──→ warning(since)
///   ↑                              │                                        │
///   └──[value≤recovery]────────────┘                                        │
///   ↑                                                                       │
///   └──[value≤recovery, emit recovery]──────────────────────────────────────┘
///                                                                           │
///   warning ──[value>critical]──→ critical(since)                           │
///                                    │                                      │
///                                    └──[value≤recovery, emit recovery]─────┘
/// ```
public final class MetricsThresholdDetector: MetricsDetector {

    /// Internal state of the detector.
    public enum State: Sendable, Equatable {
        case normal
        case elevated(since: Date)
        case warning(since: Date)
        case critical(since: Date)
    }

    // MARK: - MetricsDetector conformance

    public let id: String
    public var isEnabled: Bool = true

    // MARK: - Configuration

    private let config: MetricsThresholdConfig
    private let extractor: @Sendable (SystemMetrics) -> Double

    // MARK: - Runtime state

    public private(set) var currentState: State = .normal
    private var lastValue: Double = 0

    /// Creates a MetricsThresholdDetector.
    /// - Parameters:
    ///   - config: Threshold configuration.
    ///   - extractor: Closure that extracts the metric value from SystemMetrics.
    public init(
        config: MetricsThresholdConfig,
        extractor: @escaping @Sendable (SystemMetrics) -> Double
    ) {
        self.config = config
        self.id = config.id
        self.extractor = extractor
    }

    // MARK: - Processing

    public func process(_ metrics: SystemMetrics) -> Alert? {
        lastValue = extractor(metrics)
        // Actual state transitions happen in tick(at:) for wall-clock accuracy
        return nil
    }

    public func tick(at now: Date) -> [Alert] {
        guard isEnabled else { return [] }

        let value = lastValue
        let recovered = value <= config.recoveryThreshold
        let aboveWarning = value > config.warningThreshold
        let aboveCritical = value > config.criticalThreshold

        switch currentState {
        case .normal:
            return tickFromNormal(
                aboveWarning: aboveWarning, now: now
            )
        case .elevated(let since):
            return tickFromElevated(
                since: since,
                recovered: recovered,
                aboveWarning: aboveWarning,
                aboveCritical: aboveCritical,
                now: now
            )
        case .warning:
            return tickFromWarning(
                recovered: recovered,
                aboveCritical: aboveCritical,
                now: now
            )
        case .critical:
            return tickFromCritical(
                recovered: recovered, now: now
            )
        }
    }

    private func tickFromNormal(
        aboveWarning: Bool, now: Date
    ) -> [Alert] {
        if aboveWarning {
            currentState = .elevated(since: now)
        }
        return []
    }

    private func tickFromElevated(
        since: Date,
        recovered: Bool,
        aboveWarning: Bool,
        aboveCritical: Bool,
        now: Date
    ) -> [Alert] {
        if !aboveWarning || recovered {
            currentState = .normal
            return []
        }
        if now.timeIntervalSince(since) >= config.sustainedDuration {
            if aboveCritical {
                currentState = .critical(since: now)
                return [makeAlert(severity: .critical, timestamp: now)]
            }
            currentState = .warning(since: now)
            return [makeAlert(severity: .warning, timestamp: now)]
        }
        return []
    }

    private func tickFromWarning(
        recovered: Bool,
        aboveCritical: Bool,
        now: Date
    ) -> [Alert] {
        if recovered {
            currentState = .normal
            return [makeRecoveryAlert(timestamp: now)]
        }
        if aboveCritical {
            currentState = .critical(since: now)
            return [makeAlert(severity: .critical, timestamp: now)]
        }
        return []
    }

    private func tickFromCritical(
        recovered: Bool, now: Date
    ) -> [Alert] {
        if recovered {
            currentState = .normal
            return [makeRecoveryAlert(timestamp: now)]
        }
        return []
    }

    // MARK: - Helpers

    private func makeAlert(severity: Severity, timestamp: Date) -> Alert {
        let formatted = config.formatValue(lastValue)
        return Alert(
            detectorID: id,
            severity: severity,
            title: L10n.tr(config.titleKey),
            description: L10n.tr(config.descriptionKey(formatted)),
            suggestion: L10n.tr(config.suggestionKey),
            timestamp: timestamp
        )
    }

    private func makeRecoveryAlert(timestamp: Date) -> Alert {
        let title = "\(L10n.tr(config.titleKey)) — \(L10n.tr(.alertRecoveredSuffix))"
        return Alert(
            detectorID: id,
            severity: .info,
            title: title,
            description: L10n.tr(.alertRecoveredDesc),
            suggestion: "",
            timestamp: timestamp,
            ttl: 30
        )
    }
}
