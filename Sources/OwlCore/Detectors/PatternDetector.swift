import Foundation

/// Protocol for all pattern detectors in the detection pipeline.
///
/// Each detector watches for a specific anomaly pattern in macOS unified log entries.
/// Detectors run on a single background actor — no internal locking needed.
public protocol PatternDetector: AnyObject {
    /// Unique identifier for this detector (e.g. "P01", "P02").
    var id: String { get }

    /// Whether this detector is active. Disabled detectors are skipped by the pipeline.
    var isEnabled: Bool { get set }

    /// Fast O(1) pre-filter to decide if this detector is interested in the log entry.
    /// Typically uses `String.contains()` or prefix matching — no regex here.
    func accepts(_ entry: LogEntry) -> Bool

    /// Process a log entry and optionally produce an alert.
    /// Only called if `accepts()` returned true. Must complete in O(1) time.
    func process(_ entry: LogEntry) -> Alert?

    /// Periodic maintenance using the detector's current internal clock.
    func tick() -> [Alert]

    /// Periodic maintenance called by the pipeline (every 60s by default).
    /// Returns any alerts generated during maintenance (e.g. StateDetector leak detection).
    func tick(at now: Date) -> [Alert]
}

public extension PatternDetector {
    func tick(at now: Date) -> [Alert] {
        tick()
    }
}
