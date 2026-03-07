import Foundation

/// P07 — Process Crash Signal pattern configuration.
///
/// Detects services exiting due to fatal signals (SIGKILL, SIGSEGV, SIGABRT).
/// Uses RateDetector with capture group extraction of service name.
///
/// - Regex: extracts service name from "exited due to" messages
/// - Window: 3600 seconds (1 hour)
/// - Warning: 3 events/window per service
/// - Critical: 10 events/window per service
/// - Cooldown: 600 seconds
public enum CrashSignalPattern {

    public static let id = "process_crash_signal"

    public static func makeDetector() -> RateDetector {
        RateDetector(config: RateConfig(
            id: id,
            regex: #"Service\s+(\S+)\s+exited due to\s+SIG\w+"#,
            groupBy: .captureGroup,
            windowSeconds: 3600,
            warningRate: 3,
            criticalRate: 10,
            cooldownInterval: 600,
            maxGroups: 100,
            title: L10n.tr(.alertCrashSignalTitle),
            descriptionTemplate: L10n.tr(.alertCrashSignalDesc("{key}", "{window}", "{count}")),
            suggestion: L10n.tr(.alertCrashSignalSuggestion),
            acceptsFilter: "exited due to"
        ))
    }
}
