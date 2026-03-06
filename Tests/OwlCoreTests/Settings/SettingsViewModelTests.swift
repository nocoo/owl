import Testing
import Foundation
@testable import OwlCore

@Suite("SettingsViewModel")
struct SettingsViewModelTests {

    @MainActor
    private func makeViewModel() -> (SettingsViewModel, AppSettings) {
        let suite = "owl.test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            let settings = AppSettings()
            return (SettingsViewModel(settings: settings), settings)
        }
        let settings = AppSettings(defaults: defaults)
        return (SettingsViewModel(settings: settings), settings)
    }

    @Test @MainActor
    func initialStateLoadsFromSettings() {
        let (viewModel, _) = makeViewModel()
        #expect(!viewModel.launchAtLogin)
        for id in DetectorCatalog.allIDs {
            #expect(viewModel.detectorStates[id] == true)
        }
    }

    @Test @MainActor
    func toggleLaunchAtLoginPersists() {
        let (viewModel, settings) = makeViewModel()
        viewModel.launchAtLogin = true
        #expect(settings.launchAtLogin)
    }

    @Test @MainActor
    func toggleDetectorPersists() {
        let (viewModel, settings) = makeViewModel()
        viewModel.detectorStates["thermal_throttling"] = false
        #expect(
            !settings.isDetectorEnabled("thermal_throttling")
        )
    }

    @Test @MainActor
    func preExistingDisabledDetectorLoadsCorrectly() {
        let suite = "owl.test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return
        }
        let settings = AppSettings(defaults: defaults)
        settings.setDetectorEnabled(
            "network_failure", enabled: false
        )

        let viewModel = SettingsViewModel(settings: settings)
        #expect(viewModel.detectorStates["network_failure"] == false)
        #expect(
            viewModel.detectorStates["thermal_throttling"] == true
        )
    }

    @Test @MainActor
    func detectorStatesCountMatchesCatalog() {
        let (viewModel, _) = makeViewModel()
        #expect(
            viewModel.detectorStates.count
                == DetectorCatalog.allIDs.count
        )
    }
}
