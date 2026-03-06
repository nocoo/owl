import Foundation

/// A tracked unpaired assertion awaiting its release event.
struct TrackedAssertion {
    let id: String
    let source: String
    let type: String
    let createdAt: Date
    var alertedSeverity: Severity?
}

/// State-based pattern detector for paired event tracking (Created/Released).
///
/// Tracks unpaired "Created" events and emits alerts during `tick()` when
/// assertions remain unreleased beyond configured age thresholds.
/// Used for detecting resource leaks (e.g. sleep assertion leaks).
public final class StateDetector: PatternDetector {

    // MARK: - PatternDetector conformance

    public let id: String
    public var isEnabled: Bool = true

    // MARK: - Configuration

    private let config: StateConfig
    private let compiledCreatedRegex: NSRegularExpression?
    private let compiledReleasedRegex: NSRegularExpression?

    // MARK: - Runtime state

    /// Unpaired assertions keyed by assertion ID.
    private var pending: [String: TrackedAssertion] = [:]

    /// Insertion order for FIFO eviction.
    private var insertionOrder: [String] = []

    /// Current time reference (updated on each process call, used by tick).
    private var currentTime = Date()

    /// Number of currently tracked unpaired assertions (exposed for testing).
    public var pendingCount: Int { pending.count }

    public init(config: StateConfig) {
        self.config = config
        self.id = config.id
        self.compiledCreatedRegex = try? NSRegularExpression(pattern: config.createdRegex)
        self.compiledReleasedRegex = try? NSRegularExpression(pattern: config.releasedRegex)
    }

    public func accepts(_ entry: LogEntry) -> Bool {
        entry.eventMessage.contains(config.acceptsFilter)
    }

    public func process(_ entry: LogEntry) -> Alert? {
        currentTime = entry.timestamp

        // Try Created pattern first
        if let created = matchCreated(entry.eventMessage) {
            trackCreated(
                id: created.id,
                type: created.type,
                source: created.source,
                timestamp: entry.timestamp
            )
            return nil // Created events never produce alerts
        }

        // Try Released pattern
        if let releasedID = matchReleased(entry.eventMessage) {
            pending.removeValue(forKey: releasedID)
            insertionOrder.removeAll { $0 == releasedID }
            return nil // Normal pairing — no alert
        }

        return nil
    }

    public func tick() -> [Alert] {
        var alerts: [Alert] = []
        var keysToRemove: [String] = []

        for (assertionID, var assertion) in pending {
            let age = currentTime.timeIntervalSince(assertion.createdAt)

            // Clean up super-old entries (3x critical age)
            if age > config.criticalAge * 3 {
                keysToRemove.append(assertionID)
                continue
            }

            // Check critical threshold
            if age >= config.criticalAge && assertion.alertedSeverity != .critical {
                assertion.alertedSeverity = .critical
                pending[assertionID] = assertion
                alerts.append(makeAlert(
                    assertion: assertion,
                    age: age,
                    severity: .critical
                ))
            }
            // Check warning threshold
            else if age >= config.warningAge && assertion.alertedSeverity == nil {
                assertion.alertedSeverity = .warning
                pending[assertionID] = assertion
                alerts.append(makeAlert(
                    assertion: assertion,
                    age: age,
                    severity: .warning
                ))
            }
        }

        for key in keysToRemove {
            pending.removeValue(forKey: key)
            insertionOrder.removeAll { $0 == key }
        }

        return alerts
    }

    /// Advance internal time reference for testing purposes.
    public func advanceTimeForTesting(to date: Date) {
        currentTime = date
    }

    // MARK: - Private helpers

    private struct CreatedMatch {
        let id: String
        let type: String
        let source: String
    }

    private func matchCreated(_ message: String) -> CreatedMatch? {
        guard let regex = compiledCreatedRegex else { return nil }

        let range = NSRange(message.startIndex..., in: message)
        guard let match = regex.firstMatch(in: message, range: range),
              match.numberOfRanges >= 4,
              let idRange = Range(match.range(at: 1), in: message),
              let typeRange = Range(match.range(at: 2), in: message),
              let sourceRange = Range(match.range(at: 3), in: message) else {
            return nil
        }

        return CreatedMatch(
            id: String(message[idRange]),
            type: String(message[typeRange]),
            source: String(message[sourceRange])
        )
    }

    private func matchReleased(_ message: String) -> String? {
        guard let regex = compiledReleasedRegex else { return nil }

        let range = NSRange(message.startIndex..., in: message)
        guard let match = regex.firstMatch(in: message, range: range),
              match.numberOfRanges >= 2,
              let idRange = Range(match.range(at: 1), in: message) else {
            return nil
        }

        return String(message[idRange])
    }

    private func trackCreated(id: String, type: String, source: String, timestamp: Date) {
        // Evict oldest if at capacity
        while pending.count >= config.maxTracked, let oldest = insertionOrder.first {
            pending.removeValue(forKey: oldest)
            insertionOrder.removeFirst()
        }

        pending[id] = TrackedAssertion(
            id: id,
            source: source,
            type: type,
            createdAt: timestamp
        )
        insertionOrder.append(id)
    }

    private func makeAlert(assertion: TrackedAssertion, age: TimeInterval, severity: Severity) -> Alert {
        let description = config.descriptionTemplate
            .replacingOccurrences(of: "{id}", with: assertion.id)
            .replacingOccurrences(of: "{type}", with: assertion.type)
            .replacingOccurrences(of: "{source}", with: assertion.source)
            .replacingOccurrences(of: "{age}", with: String(format: "%.0f", age))

        return Alert(
            detectorID: id,
            severity: severity,
            title: config.title,
            description: description,
            suggestion: config.suggestion,
            timestamp: currentTime
        )
    }
}
