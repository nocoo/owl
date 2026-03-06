import Foundation

/// Direction of threshold comparison.
public enum Comparison: Sendable {
    /// Value below threshold is anomalous (e.g. thermal power budget dropping).
    case lessThan
    /// Value above threshold is anomalous (e.g. disk flush latency rising).
    case greaterThan

    /// Returns true if `value` triggers the threshold in this comparison direction.
    public func triggers(value: Double, threshold: Double) -> Bool {
        switch self {
        case .lessThan:
            return value < threshold
        case .greaterThan:
            return value > threshold
        }
    }

    /// Returns true if `value` has recovered past the recovery threshold.
    public func recovered(value: Double, recoveryThreshold: Double) -> Bool {
        switch self {
        case .lessThan:
            return value >= recoveryThreshold
        case .greaterThan:
            return value <= recoveryThreshold
        }
    }
}
