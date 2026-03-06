import SwiftUI

/// Section displaying active alerts, or an "all clear" empty state.
public struct ActiveAlertsSection: View {
    let alerts: [Alert]

    public init(alerts: [Alert]) {
        self.alerts = alerts
    }

    public var body: some View {
        if alerts.isEmpty {
            emptyState
        } else {
            alertList
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24))
                .foregroundStyle(.green)
            Text("System Running Normally")
                .font(.system(size: 12, weight: .medium))
            Text("No anomalies detected")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var alertList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Active Alerts")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

            ForEach(Array(alerts.enumerated()), id: \.offset) { _, alert in
                AlertRow(alert: alert)
                if alert != alerts.last {
                    Divider()
                        .padding(.leading, 36)
                }
            }
        }
    }
}
