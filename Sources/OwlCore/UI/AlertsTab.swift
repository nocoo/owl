import SwiftUI

/// Alerts tab in Settings showing active and recent alerts.
public struct AlertsTab: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        Group {
            if appState.activeAlerts.isEmpty,
                appState.alertHistory.isEmpty {
                emptyState
            } else {
                alertList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 16))
                .foregroundStyle(.green)
            Text("No Alerts")
                .font(.system(size: 16, weight: .medium))
            Text("System is running normally")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var alertList: some View {
        List {
            if !appState.activeAlerts.isEmpty {
                Section("Active") {
                    ForEach(
                        Array(
                            appState.activeAlerts
                                .enumerated()
                        ),
                        id: \.offset
                    ) { _, alert in
                        AlertRow(alert: alert)
                            .listRowInsets(
                                EdgeInsets()
                            )
                    }
                }
            }

            if !appState.alertHistory.isEmpty {
                Section("Recent History") {
                    ForEach(
                        Array(
                            appState.alertHistory
                                .prefix(50)
                                .enumerated()
                        ),
                        id: \.offset
                    ) { _, alert in
                        AlertRow(alert: alert)
                            .listRowInsets(
                                EdgeInsets()
                            )
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}
