import SwiftUI

/// A single alert row showing severity icon, title, description,
/// suggestion, and relative timestamp.
public struct AlertRow: View {
    let alert: Alert

    public init(alert: Alert) {
        self.alert = alert
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            severityIcon
                .frame(width: 16, height: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(alert.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(relativeTime)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Text(alert.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !alert.suggestion.isEmpty {
                    Text(alert.suggestion)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var severityIcon: some View {
        switch alert.severity {
        case .critical:
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .info:
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
        case .normal:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    private var relativeTime: String {
        let interval = Date().timeIntervalSince(alert.timestamp)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
}
