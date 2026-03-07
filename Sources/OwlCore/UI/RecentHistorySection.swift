import SwiftUI

/// Section showing the most recent expired alerts (up to 5).
public struct RecentHistorySection: View {
    let history: [Alert]

    /// Maximum number of history items to display.
    private let maxItems = 5

    public init(history: [Alert]) {
        self.history = history
    }

    public var body: some View {
        if history.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.tr(.recentEvents))
                    .font(OwlFont.alertSectionHeader)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)

                ForEach(
                    Array(history.prefix(maxItems).enumerated()),
                    id: \.offset
                ) { _, alert in
                    HistoryRow(alert: alert)
                }
            }
        }
    }
}
