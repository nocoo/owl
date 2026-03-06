import AppKit
import SwiftUI

/// A compact row for a historical (expired) alert. Tap to copy.
public struct HistoryRow: View {
    let alert: Alert
    @State private var showCopied = false

    private static let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt
    }()

    public init(alert: Alert) {
        self.alert = alert
    }

    public var body: some View {
        Button(action: copyToClipboard) {
            HStack(spacing: 8) {
                Text(Self.timeFormatter.string(
                    from: alert.timestamp
                ))
                .font(
                    .system(size: 10, design: .monospaced)
                )
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .trailing)

                statusIcon
                    .frame(width: 12, height: 12)

                Text(alert.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)

                Spacer()

                if showCopied {
                    Text("Copied")
                        .font(.system(size: 9))
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            alert.clipboardText, forType: .string
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1
        ) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopied = false
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch alert.severity {
        case .normal, .info:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        case .warning:
            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )
            .font(.system(size: 10))
            .foregroundStyle(.yellow)
        case .critical:
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        }
    }
}
