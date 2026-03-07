import Foundation

/// P02 — Process Crash-Loop pattern configuration.
///
/// Detects applications that repeatedly crash and relaunch by monitoring
/// launchservicesd QUIT messages. Uses RateDetector with capture group
/// extraction of the app bundle name.
///
/// - Regex: extracts app name from QUIT messages
/// - Window: 60 seconds
/// - Warning: 5 events/window
/// - Critical: 20 events/window
/// - Cooldown: 120 seconds
public enum CrashLoopPattern {

    public static let id = "process_crash_loop"

    public static func makeDetector() -> RateDetector {
        RateDetector(config: RateConfig(
            id: id,
            regex: #"QUIT:.*name\s*=\s*"([^"]+)""#,
            groupBy: .captureGroup,
            windowSeconds: 60,
            warningRate: 5,
            criticalRate: 20,
            cooldownInterval: 120,
            maxGroups: 50,
            titleKey: .alertCrashLoopTitle,
            descriptionTemplateKey: .alertCrashLoopDesc("{key}", "{window}", "{count}"),
            suggestionKey: .alertCrashLoopSuggestion,
            acceptsFilter: "QUIT:"
        ))
    }
}
