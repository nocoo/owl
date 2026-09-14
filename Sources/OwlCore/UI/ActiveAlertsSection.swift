import SwiftUI

/// Section displaying active alerts.
public struct ActiveAlertsSection: View {
    let alerts: [Alert]

    public init(alerts: [Alert]) {
        self.alerts = alerts
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.tr(.activeAlerts))
                    .font(OwlFont.alertSectionHeader)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                if alerts.count > 3 {
                    Spacer()
                    Text(L10n.tr(.totalCount(alerts.count)))
                        .font(OwlFont.alertCountBadge)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(
                    Array(alerts.enumerated()),
                    id: \.offset
                ) { _, alert in
                    AlertRow(alert: alert)
                    if alert != alerts.last {
                        Divider()
                            .padding(.leading, 36)
                    }
                }
            }
        }
    }
}
