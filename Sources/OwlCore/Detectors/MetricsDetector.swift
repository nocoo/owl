import Foundation

/// Protocol for metrics-based detectors in the detection pipeline.
///
/// Unlike `PatternDetector` (which processes log entries), `MetricsDetector`
/// processes periodic `SystemMetrics` snapshots to detect sustained conditions
/// such as high CPU usage or thermal pressure.
///
/// Detectors run on the `DetectorPipeline` actor -- no internal locking needed.
public protocol MetricsDetector: AnyObject {
    /// Unique identifier for this detector (e.g. "sustained_high_cpu").
    var id: String { get }

    /// Whether this detector is active. Disabled detectors are skipped by the pipeline.
    var isEnabled: Bool { get set }

    /// Process a metrics snapshot and optionally produce an alert.
    /// Called every time new metrics are polled.
    func process(_ metrics: SystemMetrics) -> Alert?

    /// Periodic maintenance called by the pipeline.
    /// Returns any time-based alerts (e.g., sustained duration thresholds).
    func tick(at now: Date) -> [Alert]
}
