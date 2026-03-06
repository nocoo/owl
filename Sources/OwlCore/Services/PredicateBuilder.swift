import Foundation

/// Describes a log source for predicate filtering.
public enum LogSource: Hashable, Sendable {
    /// Filter by process name (e.g. `process == 'kernel'`).
    case process(String)
    /// Filter by subsystem (e.g. `subsystem == 'com.apple.network'`).
    case subsystem(String)
    /// A compound predicate expression (parenthesized in output).
    /// Use for complex filters that combine multiple conditions.
    case compound(String)
}

/// Builds the `--predicate` string for `log stream` based on enabled patterns.
///
/// Design: Coarse filtering at the predicate level (process/subsystem only).
/// Fine filtering happens in each detector's `accepts()` method.
public enum PredicateBuilder {

    // MARK: - Pattern-to-source mapping

    /// Maps each pattern ID to the log sources it requires.
    /// Based on docs/03-patterns.md predicate specifications.
    private static let patternSourceMap: [String: [LogSource]] = [
        // P01 — Thermal: kernel
        ThermalPattern.id: [.process("kernel")],
        // P02 — CrashLoop: launchservicesd
        CrashLoopPattern.id: [.process("launchservicesd")],
        // P03 — DiskFlush: kernel
        DiskFlushPattern.id: [.process("kernel")],
        // P04 — WiFi: airportd
        WiFiPattern.id: [.process("airportd")],
        // P05 — Sandbox: kernel
        SandboxPattern.id: [.process("kernel")],
        // P06 — SleepAssertion: powerd
        SleepAssertionPattern.id: [.process("powerd")],
        // P07 — CrashSignal: launchd
        CrashSignalPattern.id: [.process("launchd")],
        // P08 — Bluetooth: bluetoothd
        BluetoothPattern.id: [.process("bluetoothd")],
        // P09 — TCC: tccd
        TCCPattern.id: [.process("tccd")],
        // P10 — Jetsam: kernel
        JetsamPattern.id: [.process("kernel")],
        // P11 — AppHang: WindowServer
        AppHangPattern.id: [.process("WindowServer")],
        // P12 — Network: precise sub-filter on com.apple.network
        NetworkPattern.id: [.compound(
            "subsystem == 'com.apple.network'"
            + " AND ("
            + "messageType == 16"
            + " OR eventMessage CONTAINS 'connection_failed'"
            + " OR eventMessage CONTAINS 'Connection reset'"
            + " OR eventMessage CONTAINS 'nw_endpoint_flow_failed'"
            + ")"
        )],
        // P13 — USB: kernel
        USBPattern.id: [.process("kernel")],
        // P14 — DarkWake: kernel + powerd
        DarkWakePattern.id: [.process("kernel"), .process("powerd")]
    ]

    /// All known pattern IDs.
    public static var allPatternIDs: [String] {
        Array(patternSourceMap.keys).sorted()
    }

    /// Returns the log sources for a given pattern ID.
    /// Empty array if the pattern ID is unknown.
    public static func sources(for patternID: String) -> Set<LogSource> {
        Set(patternSourceMap[patternID] ?? [])
    }

    // MARK: - Predicate building

    /// Build the full predicate string covering all patterns.
    public static func buildAll() -> String {
        build(enabledPatternIDs: Set(patternSourceMap.keys))
    }

    /// Build a predicate string for the given set of enabled pattern IDs.
    /// Unknown IDs are silently ignored. Returns empty string if no valid IDs.
    public static func build(
        enabledPatternIDs: Set<String>
    ) -> String {
        // Collect unique log sources from all enabled patterns
        var allSources = Set<LogSource>()
        for patternID in enabledPatternIDs {
            if let sources = patternSourceMap[patternID] {
                allSources.formUnion(sources)
            }
        }

        guard !allSources.isEmpty else { return "" }

        // Separate into process, subsystem, and compound clauses
        var processClauses: [String] = []
        var subsystemClauses: [String] = []
        var compoundClauses: [String] = []

        for source in allSources {
            switch source {
            case .process(let name):
                processClauses.append("process == '\(name)'")
            case .subsystem(let name):
                subsystemClauses.append("subsystem == '\(name)'")
            case .compound(let expr):
                compoundClauses.append("(\(expr))")
            }
        }

        // Sort for deterministic output
        processClauses.sort()
        subsystemClauses.sort()
        compoundClauses.sort()

        let allClauses = processClauses + subsystemClauses
            + compoundClauses
        return allClauses.joined(separator: " OR ")
    }
}
