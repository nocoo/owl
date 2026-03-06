import SwiftUI

/// Root SwiftUI view for the popover.
///
/// Composes SystemOverviewBar, ActiveAlertsSection,
/// RecentHistorySection, and BottomBar into the full popover layout.
public struct PopoverContentView: View {
    @ObservedObject var appState: AppState

    let onSettings: () -> Void
    let onQuit: () -> Void

    public init(
        appState: AppState,
        onSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.appState = appState
        self.onSettings = onSettings
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(spacing: 0) {
            SystemOverviewBar(
                cpuUsage: appState.metrics.cpuUsage,
                memoryPressure: appState.metrics.memoryPressure
            )

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ActiveAlertsSection(alerts: appState.activeAlerts)

                    if !appState.alertHistory.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                        RecentHistorySection(
                            history: appState.alertHistory
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 340)

            Divider()

            BottomBar(
                onSettings: onSettings,
                onQuit: onQuit
            )
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }
}
