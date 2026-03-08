import SwiftUI

/// Alerts tab in Settings showing active and recent alerts.
public struct AlertsTab: View {
    var appState: AppState

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
                .foregroundStyle(OwlSeverityColor.normal)
            Text(L10n.tr(.noAlerts))
                .font(.system(size: 16, weight: .medium))
            Text(L10n.tr(.systemRunningNormallyShort))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var alertList: some View {
        List {
            if !appState.activeAlerts.isEmpty {
                Section(L10n.tr(.sectionActive)) {
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
                Section(L10n.tr(.sectionRecentHistory)) {
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
