import Foundation

/// Persists user preferences via UserDefaults.
///
/// All keys are namespaced with `owl.` to avoid collisions.
/// Detector enable/disable uses `owl.detector.<id>.enabled`.
/// The backing store is injectable for testing.
public final class AppSettings {

    private let defaults: UserDefaults

    // MARK: - Keys

    private enum Keys {
        static let launchAtLogin = "owl.launchAtLogin"
        static func detectorEnabled(_ id: String) -> String {
            "owl.detector.\(id).enabled"
        }
    }

    // MARK: - Init

    /// Creates an AppSettings instance.
    /// - Parameter defaults: The UserDefaults store (default: `.standard`).
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - General

    /// Whether the app should launch at login.
    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }

    // MARK: - Detector Toggle

    /// Returns whether a detector is enabled. Defaults to `true` if never set.
    public func isDetectorEnabled(_ id: String) -> Bool {
        let key = Keys.detectorEnabled(id)
        guard defaults.object(forKey: key) != nil else {
            return true // default: all detectors on
        }
        return defaults.bool(forKey: key)
    }

    /// Sets a detector's enabled state.
    public func setDetectorEnabled(_ id: String, enabled: Bool) {
        defaults.set(enabled, forKey: Keys.detectorEnabled(id))
    }

    /// Returns enabled state for all given detector IDs.
    public func enabledDetectorIDs(
        from allIDs: [String]
    ) -> Set<String> {
        Set(allIDs.filter { isDetectorEnabled($0) })
    }

    /// Resets a detector to its default (enabled) state by removing the key.
    public func resetDetector(_ id: String) {
        defaults.removeObject(
            forKey: Keys.detectorEnabled(id)
        )
    }

    /// Resets all settings to defaults.
    public func resetAll(detectorIDs: [String]) {
        defaults.removeObject(forKey: Keys.launchAtLogin)
        for id in detectorIDs {
            defaults.removeObject(
                forKey: Keys.detectorEnabled(id)
            )
        }
    }
}
