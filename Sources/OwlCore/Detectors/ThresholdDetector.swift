import Foundation

/// Threshold-based pattern detector with state machine, debounce, and hysteresis recovery.
///
/// State machine: Normal → Pending → Warning → Critical → Normal (recovery)
/// - Pending: value in warning zone, waiting for debounce timer
/// - Warning: debounce expired, value still in warning zone
/// - Critical: value crossed critical threshold
/// - Recovery (→ Normal): value crossed recovery threshold (hysteresis)
public final class ThresholdDetector: PatternDetector {

    /// Internal state of the detector.
    public enum State: Sendable, Equatable {
        case normal
        case pending
        case warning
        case critical
    }

    // MARK: - PatternDetector conformance

    public let id: String
    public var isEnabled: Bool = true

    // MARK: - Configuration

    private let config: ThresholdConfig
    private let compiledRegex: NSRegularExpression?

    // MARK: - Runtime state

    public private(set) var currentState: State = .normal
    public private(set) var lastValue: Double = 0
    private var pendingSince: Date?

    public init(config: ThresholdConfig) {
        self.config = config
        self.id = config.id
        self.compiledRegex = try? NSRegularExpression(pattern: config.regex)
    }

    public func accepts(_ entry: LogEntry) -> Bool {
        entry.eventMessage.contains(config.acceptsFilter)
    }

    public func process(_ entry: LogEntry) -> Alert? {
        guard let value = extractValue(from: entry.eventMessage) else {
            return nil
        }

        lastValue = value
        let comparison = config.comparison

        switch currentState {
        case .normal:
            return handleNormal(value: value, comparison: comparison, timestamp: entry.timestamp)
        case .pending:
            return handlePending(value: value, comparison: comparison, timestamp: entry.timestamp)
        case .warning:
            return handleWarning(value: value, comparison: comparison, timestamp: entry.timestamp)
        case .critical:
            return handleCritical(value: value, comparison: comparison, timestamp: entry.timestamp)
        }
    }

    public func tick() -> [Alert] {
        []
    }

    public func tick(at now: Date) -> [Alert] {
        // ThresholdDetector does not produce time-based alerts
        []
    }

    // MARK: - State handlers

    private func handleNormal(
        value: Double,
        comparison: Comparison,
        timestamp: Date
    ) -> Alert? {
        if comparison.triggers(value: value, threshold: config.criticalThreshold) {
            // Jump straight to critical
            currentState = .critical
            pendingSince = nil
            return makeAlert(severity: .critical, value: value, timestamp: timestamp)
        } else if comparison.triggers(value: value, threshold: config.warningThreshold) {
            if config.debounce <= 0 {
                // Zero debounce: immediate transition to warning
                currentState = .warning
                return makeAlert(severity: .warning, value: value, timestamp: timestamp)
            }
            currentState = .pending
            pendingSince = timestamp
        }
        return nil
    }

    private func handlePending(
        value: Double,
        comparison: Comparison,
        timestamp: Date
    ) -> Alert? {
        // Check for critical first — bypasses debounce
        if comparison.triggers(value: value, threshold: config.criticalThreshold) {
            currentState = .critical
            pendingSince = nil
            return makeAlert(severity: .critical, value: value, timestamp: timestamp)
        }

        // Check if value recovered
        if !comparison.triggers(value: value, threshold: config.warningThreshold) {
            currentState = .normal
            pendingSince = nil
            return nil
        }

        // Check if debounce expired
        if let since = pendingSince,
           timestamp.timeIntervalSince(since) >= config.debounce {
            currentState = .warning
            pendingSince = nil
            return makeAlert(severity: .warning, value: value, timestamp: timestamp)
        }

        return nil
    }

    private func handleWarning(
        value: Double,
        comparison: Comparison,
        timestamp: Date
    ) -> Alert? {
        // Check recovery (hysteresis)
        if comparison.recovered(value: value, recoveryThreshold: config.recoveryThreshold) {
            currentState = .normal
            return makeRecoveryAlert(timestamp: timestamp)
        }

        // Check escalation to critical
        if comparison.triggers(value: value, threshold: config.criticalThreshold) {
            currentState = .critical
            return makeAlert(severity: .critical, value: value, timestamp: timestamp)
        }

        // Still in warning zone — no state change, no alert
        return nil
    }

    private func handleCritical(
        value: Double,
        comparison: Comparison,
        timestamp: Date
    ) -> Alert? {
        // Check recovery (hysteresis)
        if comparison.recovered(value: value, recoveryThreshold: config.recoveryThreshold) {
            currentState = .normal
            return makeRecoveryAlert(timestamp: timestamp)
        }

        // Check downgrade to warning (value improved but not recovered)
        if !comparison.triggers(value: value, threshold: config.criticalThreshold) &&
            comparison.triggers(value: value, threshold: config.warningThreshold) {
            currentState = .warning
            return makeAlert(severity: .warning, value: value, timestamp: timestamp)
        }

        // Still critical — no state change
        return nil
    }

    // MARK: - Helpers

    private func extractValue(from message: String) -> Double? {
        guard let regex = compiledRegex else { return nil }

        let range = NSRange(message.startIndex..., in: message)
        guard let match = regex.firstMatch(in: message, range: range),
              match.numberOfRanges >= 2 else {
            return nil
        }

        guard let captureRange = Range(match.range(at: 1), in: message) else {
            return nil
        }

        return Double(message[captureRange])
    }

    private func makeAlert(severity: Severity, value: Double, timestamp: Date) -> Alert {
        let description = L10n.tr(config.descriptionTemplateKey).replacingOccurrences(
            of: "{value}",
            with: String(format: "%.0f", value)
        )
        return Alert(
            detectorID: id,
            severity: severity,
            title: L10n.tr(config.titleKey),
            description: description,
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
