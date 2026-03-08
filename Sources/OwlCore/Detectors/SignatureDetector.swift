import Foundation

/// Signature-diversity pattern detector using double-buffered sliding window.
///
/// Instead of counting raw events (like `RateDetector`), this detector tracks
/// the number of **distinct** signatures per group key within a time window.
/// Alerts fire when signature diversity exceeds configured thresholds.
///
/// Window strategy: double-buffer rotation every `windowSeconds / 2`.
/// Two hash sets per group (`current` and `previous`), active signatures
/// = current ∪ previous. This provides O(1) insert and approximate
/// sliding window semantics with ~1x–1.5x window coverage.
///
/// Performance: O(1) accepts, O(n) regex match per process call,
/// O(1) signature assembly + set insert.
public final class SignatureDetector: PatternDetector {

    // MARK: - PatternDetector conformance

    public let id: String
    public var isEnabled: Bool = true

    // MARK: - Configuration

    private let config: SignatureConfig
    private let compiledRegex: NSRegularExpression?

    // MARK: - Per-group tracking state

    struct GroupState {
        var currentSet: Set<String> = []
        var previousSet: Set<String> = []
        var lastSeen: Date
        var alertedSeverity: Severity?
        var cooldownUntil: Date?

        /// Count of distinct signatures across both buffers
        /// without allocating a temporary union set.
        var distinctCount: Int {
            var count = currentSet.count
            for sig in previousSet where !currentSet.contains(sig) {
                count += 1
            }
            return count
        }
    }

    /// Tracked groups keyed by the extracted group key (e.g. process name).
    private var groups: [String: GroupState] = [:]

    /// Timestamp of the last buffer rotation.
    private var lastRotation: Date?

    /// Current time reference (updated on each process call).
    private var currentTime = Date()

    /// Number of currently tracked groups (exposed for testing).
    public var groupCount: Int { groups.count }

    // MARK: - Init

    public init(config: SignatureConfig) {
        self.config = config
        self.id = config.id
        self.compiledRegex = try? NSRegularExpression(pattern: config.regex)
    }

    // MARK: - PatternDetector

    public func accepts(_ entry: LogEntry) -> Bool {
        entry.eventMessage.contains(config.acceptsFilter)
    }

    public func process(_ entry: LogEntry) -> Alert? {
        currentTime = entry.timestamp
        rotateBuffersIfNeeded(at: entry.timestamp)

        guard let match = firstMatch(in: entry.eventMessage) else {
            return nil
        }

        guard let key = captureGroup(config.keyGroupIndex, from: match, in: entry.eventMessage),
              !key.isEmpty else {
            return nil
        }

        let signature = buildSignature(from: match, in: entry.eventMessage)
        guard !signature.isEmpty else {
            return nil
        }

        if groups[key] == nil {
            evictIfNeeded()
            groups[key] = GroupState(lastSeen: entry.timestamp)
        }

        guard var state = groups[key] else { return nil }
        state.currentSet.insert(signature)
        state.lastSeen = entry.timestamp

        let distinctCount = state.distinctCount
        groups[key] = state

        if distinctCount >= config.criticalDistinct {
            return tryEmitAlert(
                key: key,
                distinctCount: distinctCount,
                severity: .critical,
                timestamp: entry.timestamp
            )
        }

        if distinctCount >= config.warningDistinct {
            return tryEmitAlert(
                key: key,
                distinctCount: distinctCount,
                severity: .warning,
                timestamp: entry.timestamp
            )
        }

        return nil
    }

    public func tick() -> [Alert] {
        rotateBuffersIfNeeded(at: currentTime)

        let staleThreshold = TimeInterval(config.windowSeconds * 2)
        let staleKeys = groups.compactMap { key, state in
            currentTime.timeIntervalSince(state.lastSeen) > staleThreshold ? key : nil
        }

        for key in staleKeys {
            groups.removeValue(forKey: key)
        }

        return []
    }

    /// Advance internal clock for testing without feeding log entries.
    public func advanceTimeForTesting(to date: Date) {
        currentTime = date
    }

    // MARK: - Private helpers

    private func firstMatch(in message: String) -> NSTextCheckingResult? {
        guard let regex = compiledRegex else { return nil }
        let range = NSRange(message.startIndex..., in: message)
        return regex.firstMatch(in: message, range: range)
    }

    private func captureGroup(
        _ index: Int,
        from match: NSTextCheckingResult,
        in message: String
    ) -> String? {
        guard index >= 0,
              index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: message) else {
            return nil
        }

        return String(message[range])
    }

    private func buildSignature(
        from match: NSTextCheckingResult,
        in message: String
    ) -> String {
        config.signatureGroupIndexes.compactMap { index in
            captureGroup(index, from: match, in: message)
                .map { config.normalizer?($0) ?? $0 }
        }.joined(separator: ":")
    }

    private func rotateBuffersIfNeeded(at timestamp: Date) {
        let rotationInterval = max(TimeInterval(config.windowSeconds) / 2, 1)

        guard let lastRotation else {
            lastRotation = timestamp
            return
        }

        let elapsed = timestamp.timeIntervalSince(lastRotation)
        guard elapsed >= rotationInterval else { return }

        let rotations = Int(elapsed / rotationInterval)

        for _ in 0..<min(rotations, 2) {
            rotateOnce()
        }

        if rotations > 2 {
            let keys = Array(groups.keys)
            for key in keys {
                var state = groups[key]
                state?.currentSet.removeAll(keepingCapacity: false)
                state?.previousSet.removeAll(keepingCapacity: false)
                if let state {
                    groups[key] = state
                }
            }
        }

        self.lastRotation = lastRotation.addingTimeInterval(rotationInterval * Double(rotations))
    }

    private func rotateOnce() {
        let keys = Array(groups.keys)
        for key in keys {
            guard var state = groups[key] else { continue }
            state.previousSet = state.currentSet
            state.currentSet.removeAll(keepingCapacity: true)
            groups[key] = state
        }
    }

    private func tryEmitAlert(
        key: String,
        distinctCount: Int,
        severity: Severity,
        timestamp: Date
    ) -> Alert? {
        guard var state = groups[key] else { return nil }

        if let until = state.cooldownUntil,
           timestamp < until {
            if let currentSeverity = state.alertedSeverity,
               severity > currentSeverity {
                state.alertedSeverity = severity
                state.cooldownUntil = cooldownDate(from: timestamp)
                groups[key] = state
                return makeAlert(
                    key: key,
                    distinctCount: distinctCount,
                    severity: severity,
                    timestamp: timestamp
                )
            }

            groups[key] = state
            return nil
        }

        if state.alertedSeverity == severity {
            groups[key] = state
            return nil
        }

        state.alertedSeverity = severity
        state.cooldownUntil = cooldownDate(from: timestamp)
        groups[key] = state

        return makeAlert(
            key: key,
            distinctCount: distinctCount,
            severity: severity,
            timestamp: timestamp
        )
    }

    private func cooldownDate(from timestamp: Date) -> Date? {
        guard config.cooldownInterval > 0 else { return nil }
        return timestamp.addingTimeInterval(config.cooldownInterval)
    }

    private func makeAlert(
        key: String,
        distinctCount: Int,
        severity: Severity,
        timestamp: Date
    ) -> Alert {
        let description = L10n.tr(config.descriptionTemplateKey)
            .replacingOccurrences(of: "{key}", with: key)
            .replacingOccurrences(of: "{count}", with: String(distinctCount))
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
        guard groups.count >= config.maxGroups else { return }

        // TODO: Extract shared grouped-detector core if another signature-based detector lands.
        // Linear scan for the oldest entry avoids O(n log n) full sort.
        let removeCount = groups.count - config.maxGroups + 1
        for _ in 0..<removeCount {
            guard let oldest = groups.min(
                by: { $0.value.lastSeen < $1.value.lastSeen }
            ) else { break }
            groups.removeValue(forKey: oldest.key)
        }
    }
}
