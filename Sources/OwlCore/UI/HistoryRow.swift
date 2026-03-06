import SwiftUI

/// A compact row for a historical (expired) alert.
public struct HistoryRow: View {
    let alert: Alert

    public init(alert: Alert) {
        self.alert = alert
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(timeText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .trailing)

            statusIcon
                .frame(width: 12, height: 12)

            Text(alert.title)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch alert.severity {
        case .normal, .info:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)
        case .critical:
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: alert.timestamp)
    }
}
