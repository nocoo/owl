import Foundation

/// A time-bucketed sliding window counter using a ring buffer.
///
/// Provides O(1) `increment()`, `advance()`, and `total` access.
/// Used by `RateDetector` to count events within a fixed time window.
public struct SlidingWindowCounter: Sendable {

    /// Number of buckets in the ring buffer.
    public let bucketCount: Int

    /// Duration of each bucket in seconds.
    public let bucketDuration: Int

    /// Total window size in seconds.
    public let windowSeconds: Int

    /// Current sum of all bucket values (maintained incrementally).
    public private(set) var total: Int = 0

    /// Ring buffer of event counts per time bucket.
    private var buckets: [Int]

    /// Index of the current (head) bucket in the ring buffer.
    private var headIndex: Int = 0

    /// Timestamp (as integer seconds) of the current head bucket.
    private var headTimestamp: Int = 0

    /// Whether this counter has been initialized with a timestamp.
    private var isInitialized = false

    public init(windowSeconds: Int, bucketDuration: Int = 1) {
        self.windowSeconds = windowSeconds
        self.bucketDuration = max(bucketDuration, 1)
        self.bucketCount = windowSeconds / max(bucketDuration, 1)
        self.buckets = [Int](repeating: 0, count: self.bucketCount)
    }

    /// Increment the counter for the given timestamp.
    public mutating func increment(at timestamp: Date) {
        advance(to: timestamp)
        buckets[headIndex] += 1
        total += 1
    }

    /// Advance the ring buffer to the given timestamp, expiring old buckets.
    public mutating func advance(to timestamp: Date) {
        let currentSecond = Int(timestamp.timeIntervalSinceReferenceDate) / bucketDuration

        if !isInitialized {
            headTimestamp = currentSecond
            isInitialized = true
            return
        }

        let elapsed = currentSecond - headTimestamp
        if elapsed <= 0 {
            return // Same bucket or backward time — no-op
        }

        if elapsed >= bucketCount {
            // Entire window expired — reset everything
            for idx in 0..<bucketCount {
                buckets[idx] = 0
            }
            total = 0
            headIndex = 0
        } else {
            // Advance bucket by bucket, clearing expired ones
            for _ in 0..<elapsed {
                headIndex = (headIndex + 1) % bucketCount
                total -= buckets[headIndex]
                buckets[headIndex] = 0
            }
        }

        headTimestamp = currentSecond
    }
}
