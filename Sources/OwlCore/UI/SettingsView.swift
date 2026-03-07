import AppKit
import SwiftUI

/// Root settings window view with tabs.
public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var appState: AppState
    let appIcon: NSImage?
    let logoImage: NSImage?

    public init(
        viewModel: SettingsViewModel,
        appState: AppState,
        appIcon: NSImage? = nil,
        logoImage: NSImage? = nil
    ) {
        self.viewModel = viewModel
        self.appState = appState
        self.appIcon = appIcon
        self.logoImage = logoImage
    }

    public var body: some View {
        TabView {
            GeneralTab(
                launchAtLogin: $viewModel.launchAtLogin,
                logoImage: logoImage ?? appIcon
            )
            .tabItem {
                Label(
                    "General",
                    systemImage: "gearshape"
                )
            }

            DetectorsTab(
                enabledStates: $viewModel.detectorStates
            )
            .tabItem {
                Label(
                    "Detectors",
                    systemImage: "sensor"
                )
            }

            AlertsTab(appState: appState)
                .tabItem {
                    Label(
                        "Alerts",
                        systemImage:
                            "exclamationmark.bubble"
                    )
                }

            ProcessTab()
                .tabItem {
                    Label(
                        "Processes",
                        systemImage: "chart.bar.doc.horizontal"
                    )
                }
        }
        .frame(width: 520, height: 520)
    }
}

/// View model for settings, backed by AppSettings.
@MainActor
public final class SettingsViewModel: ObservableObject {

    private let settings: AppSettings

    @Published public var launchAtLogin: Bool {
        didSet { settings.launchAtLogin = launchAtLogin }
    }

    @Published public var language: AppLanguage {
        didSet {
            settings.language = language
            L10n.setLanguage(language)
        }
    }

    @Published public var appearance: AppAppearance {
        didSet {
            settings.appearance = appearance
            onAppearanceChange?(appearance)
        }
    }

    @Published public var detectorStates: [String: Bool] {
        didSet {
            for (id, enabled) in detectorStates {
                settings.setDetectorEnabled(
                    id, enabled: enabled
                )
            }
        }
    }

    /// Callback invoked when a detector toggle changes.
    public var onDetectorToggle: ((
        _ id: String, _ enabled: Bool
    ) -> Void)?

    /// Callback invoked when appearance preference changes.
    public var onAppearanceChange: ((AppAppearance) -> Void)?

    public init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        self.launchAtLogin = settings.launchAtLogin
        self.language = settings.language
        self.appearance = settings.appearance

        var states: [String: Bool] = [:]
        for id in DetectorCatalog.allIDs {
            states[id] = settings.isDetectorEnabled(id)
        }
        self.detectorStates = states
    }
}
