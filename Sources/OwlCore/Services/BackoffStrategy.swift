import Foundation

/// Exponential backoff delay calculator for process restart.
///
/// Computes increasing delays: `baseDelay * 2^attempt`, capped at `maxDelay`.
/// Call `reset()` when the process has been stable for a while.
public struct BackoffStrategy: Sendable {

    /// Base delay in seconds (first restart delay).
    public let baseDelay: TimeInterval

    /// Maximum delay in seconds.
    public let maxDelay: TimeInterval

    /// Number of restart attempts so far.
    public private(set) var attemptCount: Int = 0

    public init(
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0
    ) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    /// Returns the next delay and increments the attempt counter.
    public mutating func nextDelay() -> TimeInterval {
        let delay = min(
            baseDelay * pow(2.0, Double(attemptCount)),
            maxDelay
        )
        attemptCount += 1
        return delay
    }

    /// Reset the backoff counter (e.g., after sustained stability).
    public mutating func reset() {
        attemptCount = 0
    }
}
