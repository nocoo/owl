import Testing
import Foundation
@testable import OwlCore

@Suite("AppSettings")
struct AppSettingsTests {

    /// Fresh UserDefaults suite for each test to avoid cross-contamination.
    private func makeSettings() -> AppSettings {
        let suite = "owl.test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return AppSettings()
        }
        return AppSettings(defaults: defaults)
    }

    // MARK: - Launch at Login

    @Test func launchAtLoginDefaultsToFalse() {
        let settings = makeSettings()
        #expect(!settings.launchAtLogin)
    }

    @Test func setLaunchAtLogin() {
        let settings = makeSettings()
        settings.launchAtLogin = true
        #expect(settings.launchAtLogin)
        settings.launchAtLogin = false
        #expect(!settings.launchAtLogin)
    }

    // MARK: - Detector Enable/Disable

    @Test func detectorEnabledDefaultsToTrue() {
        let settings = makeSettings()
        #expect(settings.isDetectorEnabled("thermal_throttling"))
        #expect(settings.isDetectorEnabled("process_crash_loop"))
        #expect(settings.isDetectorEnabled("nonexistent_id"))
    }

    @Test func disableDetector() {
        let settings = makeSettings()
        settings.setDetectorEnabled(
            "thermal_throttling", enabled: false
        )
        #expect(!settings.isDetectorEnabled("thermal_throttling"))
        // Other detectors unaffected
        #expect(settings.isDetectorEnabled("process_crash_loop"))
    }

    @Test func reEnableDetector() {
        let settings = makeSettings()
        settings.setDetectorEnabled(
            "thermal_throttling", enabled: false
        )
        #expect(!settings.isDetectorEnabled("thermal_throttling"))
        settings.setDetectorEnabled(
            "thermal_throttling", enabled: true
        )
        #expect(settings.isDetectorEnabled("thermal_throttling"))
    }

    @Test func enabledDetectorIDsFiltersCorrectly() {
        let settings = makeSettings()
        let allIDs = [
            "thermal_throttling",
            "process_crash_loop",
            "wifi_signal_weak"
        ]
        settings.setDetectorEnabled(
            "process_crash_loop", enabled: false
        )

        let enabled = settings.enabledDetectorIDs(from: allIDs)
        #expect(enabled.count == 2)
        #expect(enabled.contains("thermal_throttling"))
        #expect(!enabled.contains("process_crash_loop"))
        #expect(enabled.contains("wifi_signal_weak"))
    }

    @Test func resetDetectorRestoresDefault() {
        let settings = makeSettings()
        settings.setDetectorEnabled(
            "thermal_throttling", enabled: false
        )
        #expect(!settings.isDetectorEnabled("thermal_throttling"))
        settings.resetDetector("thermal_throttling")
        #expect(settings.isDetectorEnabled("thermal_throttling"))
    }

    @Test func resetAllClearsEverything() {
        let settings = makeSettings()
        settings.launchAtLogin = true
        settings.setDetectorEnabled(
            "thermal_throttling", enabled: false
        )
        settings.setDetectorEnabled(
            "wifi_signal_weak", enabled: false
        )

        settings.resetAll(detectorIDs: [
            "thermal_throttling",
            "wifi_signal_weak"
        ])

        #expect(!settings.launchAtLogin)
        #expect(settings.isDetectorEnabled("thermal_throttling"))
        #expect(settings.isDetectorEnabled("wifi_signal_weak"))
    }

    @Test func multipleDetectorsIndependent() {
        let settings = makeSettings()
        settings.setDetectorEnabled(
            "thermal_throttling", enabled: false
        )
        settings.setDetectorEnabled(
            "wifi_signal_weak", enabled: false
        )
        settings.setDetectorEnabled(
            "process_crash_loop", enabled: true
        )

        #expect(!settings.isDetectorEnabled("thermal_throttling"))
        #expect(!settings.isDetectorEnabled("wifi_signal_weak"))
        #expect(settings.isDetectorEnabled("process_crash_loop"))
        // Never-set detectors still default to true
        #expect(settings.isDetectorEnabled("dark_wake"))
    }
}
