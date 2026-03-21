import Foundation

/// Configuration for the sustained CPU detector.
public struct SustainedCPUConfig: Sendable {
    /// CPU usage percentage threshold (0–100). Values above trigger tracking.
    public let threshold: Double

    /// Duration in seconds the CPU must stay above threshold before warning.
    public let duration: TimeInterval

    /// Detector identifier.
    public let id: String

    public init(id: String, threshold: Double, duration: TimeInterval) {
        self.id = id
        self.threshold = threshold
        self.duration = duration
    }
}

/// P15 — Sustained High CPU detector.
///
/// Detects when system CPU usage stays above a threshold for a sustained period.
/// Escalates to critical when thermal state is `.critical`.
///
/// State machine:
/// ```
/// normal ──[CPU>threshold]──→ elevated(since)
///   ↑                             │
///   └──[CPU≤threshold]────────────┘
///   ↑                             │
///   │                  [duration≥config.duration]
///   │                             ↓
///   │                       warning(since)
///   │                             │
///   └──[CPU≤threshold, recovery]──┘
///   │                             │
///   │              [thermalState==.critical]
///   │                             ↓
///   │                      critical(since)
///   │                             │
///   └──[CPU≤threshold, recovery]──┘
/// ```
public final class SustainedCPUDetector: MetricsDetector {

    /// Internal state of the detector.
    public enum State: Sendable, Equatable {
        case normal
        case elevated(since: Date)
        case warning(since: Date)
        case critical(since: Date)
    }

    // MARK: - MetricsDetector conformance

    public let id: String
    public var isEnabled: Bool = true

    // MARK: - Configuration

    private let config: SustainedCPUConfig
    private let thermalStateProvider: @Sendable () -> ProcessInfo.ThermalState

    // MARK: - Runtime state

    public private(set) var currentState: State = .normal
    private var lastCPU: Double = 0

    public init(
        config: SustainedCPUConfig,
        thermalStateProvider: @escaping @Sendable () -> ProcessInfo.ThermalState = {
            ProcessInfo.processInfo.thermalState
        }
    ) {
        self.config = config
        self.id = config.id
        self.thermalStateProvider = thermalStateProvider
    }

    // MARK: - Processing

    public func process(_ metrics: SystemMetrics) -> Alert? {
        lastCPU = metrics.cpuUsage
        // Actual state transitions happen in tick(at:) for wall-clock accuracy
        return nil
    }

    public func tick(at now: Date) -> [Alert] {
        guard isEnabled else { return [] }

        let cpuHigh = lastCPU > config.threshold
        let thermalState = thermalStateProvider()

        switch currentState {
        case .normal:
            return tickFromNormal(cpuHigh: cpuHigh, now: now)
        case .elevated(let since):
            return tickFromElevated(
                since: since, cpuHigh: cpuHigh, now: now
            )
        case .warning(let since):
            return tickFromWarning(
                since: since,
                cpuHigh: cpuHigh,
                thermalState: thermalState,
                now: now
            )
        case .critical(let since):
            return tickFromCritical(
                since: since,
                cpuHigh: cpuHigh,
                thermalState: thermalState,
                now: now
            )
        }
    }

    private func tickFromNormal(
        cpuHigh: Bool, now: Date
    ) -> [Alert] {
        if cpuHigh {
            currentState = .elevated(since: now)
        }
        return []
    }

    private func tickFromElevated(
        since: Date, cpuHigh: Bool, now: Date
    ) -> [Alert] {
        if !cpuHigh {
            currentState = .normal
            return []
        }
        if now.timeIntervalSince(since) >= config.duration {
            currentState = .warning(since: now)
            return [makeAlert(severity: .warning, timestamp: now)]
        }
        return []
    }

    private func tickFromWarning(
        since: Date,
        cpuHigh: Bool,
        thermalState: ProcessInfo.ThermalState,
        now: Date
    ) -> [Alert] {
        if !cpuHigh {
            currentState = .normal
            return [makeRecoveryAlert(timestamp: now)]
        }
        if thermalState == .critical {
            currentState = .critical(since: now)
            return [makeAlert(severity: .critical, timestamp: now)]
        }
        // Re-emit warning periodically? No — AlertStateManager handles dedup.
        _ = since
        return []
    }

    private func tickFromCritical(
        since: Date,
        cpuHigh: Bool,
        thermalState: ProcessInfo.ThermalState,
        now: Date
    ) -> [Alert] {
        if !cpuHigh {
            currentState = .normal
            return [makeRecoveryAlert(timestamp: now)]
        }
        if thermalState != .critical {
            // Downgrade to warning
            currentState = .warning(since: since)
            return [makeAlert(severity: .warning, timestamp: now)]
        }
        return []
    }

    // MARK: - Helpers

    private func makeAlert(severity: Severity, timestamp: Date) -> Alert {
        Alert(
            detectorID: id,
            severity: severity,
            title: L10n.tr(.alertSustainedCPUTitle),
            description: L10n.tr(.alertSustainedCPUDesc(
                String(format: "%.0f", lastCPU)
            )),
            suggestion: L10n.tr(.alertSustainedCPUSuggestion),
            timestamp: timestamp
        )
    }

    private func makeRecoveryAlert(timestamp: Date) -> Alert {
        let title = "\(L10n.tr(.alertSustainedCPUTitle)) — \(L10n.tr(.alertRecoveredSuffix))"
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
