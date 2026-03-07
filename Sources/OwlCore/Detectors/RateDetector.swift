import Foundation

/// Rate-based pattern detector using sliding window counters with grouped counting.
///
/// Counts events within a time window, grouped by a key extracted from the log message.
/// Triggers warnings/critical alerts when event count exceeds thresholds.
/// Includes cooldown to prevent alert flooding and LRU eviction for group limits.
public final class RateDetector: PatternDetector {

    // MARK: - PatternDetector conformance

    public let id: String
    public var isEnabled: Bool = true

    // MARK: - Configuration

    private let config: RateConfig
    private let compiledRegex: NSRegularExpression?

    // MARK: - Runtime state

    /// Sliding window counters keyed by group key.
    private var counters: [String: SlidingWindowCounter] = [:]

    /// Last-seen timestamp for each group key (for LRU eviction).
    private var lastSeen: [String: Date] = [:]

    /// Cooldown expiry timestamp for each group key.
    private var cooldownUntil: [String: Date] = [:]

    /// Tracks the current alert severity per group to avoid re-alerting at the same level.
    private var groupState: [String: Severity] = [:]

    /// Current time reference (updated on each process call, used by tick).
    private var currentTime = Date()

    /// Global key used when groupBy is `.global`.
    private static let globalKey = "__global__"

    /// Number of currently tracked groups (exposed for testing).
    public var groupCount: Int { counters.count }

    public init(config: RateConfig) {
        self.config = config
        self.id = config.id
        self.compiledRegex = try? NSRegularExpression(pattern: config.regex)
    }

    public func accepts(_ entry: LogEntry) -> Bool {
        entry.eventMessage.contains(config.acceptsFilter)
    }

    public func process(_ entry: LogEntry) -> Alert? {
        // Validate regex match before counting. Messages that pass the coarse
        // acceptsFilter but fail the full regex must be silently discarded,
        // regardless of groupBy mode. Without this guard, captureGroup mode
        // falls back to __global__ key and global mode skips regex entirely.
        if let regex = compiledRegex {
            let range = NSRange(entry.eventMessage.startIndex..., in: entry.eventMessage)
            if regex.firstMatch(in: entry.eventMessage, range: range) == nil {
                return nil
            }
        }

        let key = extractKey(from: entry.eventMessage)
        currentTime = entry.timestamp

        // Get or create counter for this key
        if counters[key] == nil {
            evictIfNeeded()
            counters[key] = SlidingWindowCounter(windowSeconds: config.windowSeconds)
        }

        counters[key]?.increment(at: entry.timestamp)
        lastSeen[key] = entry.timestamp

        guard let count = counters[key]?.total else { return nil }

        // Check thresholds (critical first, then warning)
        if count >= config.criticalRate {
            return tryEmitAlert(key: key, count: count, severity: .critical, timestamp: entry.timestamp)
        } else if count >= config.warningRate {
            return tryEmitAlert(key: key, count: count, severity: .warning, timestamp: entry.timestamp)
        }

        return nil
    }

    public func tick() -> [Alert] {
        // Clean up stale groups (not seen in 2x window duration)
        let staleThreshold = TimeInterval(config.windowSeconds * 2)
        var keysToRemove: [String] = []

        for (key, lastDate) in lastSeen where currentTime.timeIntervalSince(lastDate) > staleThreshold {
            keysToRemove.append(key)
        }

        for key in keysToRemove {
            counters.removeValue(forKey: key)
            lastSeen.removeValue(forKey: key)
            cooldownUntil.removeValue(forKey: key)
            groupState.removeValue(forKey: key)
        }

        return [] // RateDetector does not produce time-based alerts
    }

    /// Advance internal time reference for testing purposes.
    public func advanceTimeForTesting(to date: Date) {
        currentTime = date
    }

    // MARK: - Private helpers

    private func extractKey(from message: String) -> String {
        if config.groupBy == .global {
            return Self.globalKey
        }

        guard let regex = compiledRegex else { return Self.globalKey }

        let range = NSRange(message.startIndex..., in: message)
        guard let match = regex.firstMatch(in: message, range: range),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: message) else {
            return Self.globalKey
        }

        return String(message[captureRange])
    }

    private func tryEmitAlert(
        key: String,
        count: Int,
        severity: Severity,
        timestamp: Date
    ) -> Alert? {
        // Check cooldown (but allow severity escalation)
        if let until = cooldownUntil[key] {
            if timestamp < until {
                // During cooldown, only allow escalation to higher severity
                if let currentSeverity = groupState[key], severity > currentSeverity {
                    // Allow escalation — update state and reset cooldown
                    groupState[key] = severity
                    cooldownUntil[key] = timestamp.addingTimeInterval(config.cooldownInterval)
                    return makeAlert(key: key, count: count, severity: severity, timestamp: timestamp)
                }
                return nil
            }
            // Cooldown expired — reset state so we can re-alert
            cooldownUntil.removeValue(forKey: key)
            groupState.removeValue(forKey: key)
        }

        // Check if already at this severity level
        if groupState[key] == severity {
            return nil
        }

        // Emit alert and start cooldown
        groupState[key] = severity
        if config.cooldownInterval > 0 {
            cooldownUntil[key] = timestamp.addingTimeInterval(config.cooldownInterval)
        }

        return makeAlert(key: key, count: count, severity: severity, timestamp: timestamp)
    }

    private func makeAlert(
        key: String,
        count: Int,
        severity: Severity,
        timestamp: Date
    ) -> Alert {
        let displayKey = key == Self.globalKey ? L10n.tr(.alertGlobalSystem) : key
        let description = L10n.tr(config.descriptionTemplateKey)
            .replacingOccurrences(of: "{key}", with: displayKey)
            .replacingOccurrences(of: "{count}", with: String(count))
            .replacingOccurrences(of: "{window}", with: String(config.windowSeconds))

        return Alert(
            detectorID: id,
            severity: severity,
            title: L10n.tr(config.titleKey),
            description: description,
            suggestion: L10n.tr(config.suggestionKey),
            timestamp: timestamp
        )
    }

    private func evictIfNeeded() {
        guard counters.count >= config.maxGroups else { return }

        // Evict least recently seen key
        let removeCount = counters.count - config.maxGroups + 1
        let sorted = lastSeen.sorted { $0.value < $1.value }

        for (key, _) in sorted.prefix(removeCount) {
            counters.removeValue(forKey: key)
            lastSeen.removeValue(forKey: key)
            cooldownUntil.removeValue(forKey: key)
            groupState.removeValue(forKey: key)
        }
    }
}
