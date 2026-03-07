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
/// O(1) hash + set insert. Memory: ~8 bytes per unique signature hash.
public final class SignatureDetector: PatternDetector {

    // MARK: - PatternDetector conformance

    public let id: String
    public var isEnabled: Bool = true

    // MARK: - Configuration

    private let config: SignatureConfig
    private let compiledRegex: NSRegularExpression?

    // MARK: - Per-group tracking state

    struct GroupState {
        var currentSet: Set<Int> = []
        var previousSet: Set<Int> = []
        var totalCount: Int = 0
        var lastSeen: Date
        var alertedSeverity: Severity?
        var cooldownUntil: Date?

        var distinctCount: Int {
            currentSet.union(previousSet).count
        }
    }

    /// Tracked groups keyed by the extracted group key (e.g. process name).
    private var groups: [String: GroupState] = [:]

    /// Insertion-order tracking for LRU eviction.
    private var groupOrder: [String] = []

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
        // TODO: implement in GREEN phase
        return nil
    }

    public func tick() -> [Alert] {
        // TODO: implement in GREEN phase
        return []
    }

    /// Advance internal clock for testing without feeding log entries.
    public func advanceTimeForTesting(to date: Date) {
        currentTime = date
    }
}
