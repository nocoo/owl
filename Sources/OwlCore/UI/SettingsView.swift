import SwiftUI

/// Root settings window view with three tabs.
public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        TabView {
            GeneralTab(
                launchAtLogin: $viewModel.launchAtLogin
            )
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            DetectorsTab(
                detectors: DetectorCatalog.all,
                enabledStates: $viewModel.detectorStates
            )
            .tabItem {
                Label("Detectors", systemImage: "sensor")
            }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 380)
    }
}

/// View model for settings, backed by AppSettings.
@MainActor
public final class SettingsViewModel: ObservableObject {

    private let settings: AppSettings

    @Published public var launchAtLogin: Bool {
        didSet { settings.launchAtLogin = launchAtLogin }
    }

    @Published public var detectorStates: [String: Bool] {
        didSet {
            for (id, enabled) in detectorStates {
                settings.setDetectorEnabled(id, enabled: enabled)
            }
        }
    }

    /// Callback invoked whenever a detector toggle changes.
    /// The wiring layer uses this to update the pipeline.
    public var onDetectorToggle: ((_ id: String, _ enabled: Bool) -> Void)?

    public init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        self.launchAtLogin = settings.launchAtLogin

        var states: [String: Bool] = [:]
        for id in DetectorCatalog.allIDs {
            states[id] = settings.isDetectorEnabled(id)
        }
        self.detectorStates = states
    }
}
