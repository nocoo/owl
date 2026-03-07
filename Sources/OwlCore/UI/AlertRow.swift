import AppKit
import SwiftUI

/// A single alert row showing severity icon, title, description,
/// suggestion, and relative timestamp. Tap to copy to clipboard.
public struct AlertRow: View {
    let alert: Alert
    @State private var showCopied = false

    public init(alert: Alert) {
        self.alert = alert
    }

    public var body: some View {
        Button(action: copyToClipboard) {
            HStack(alignment: .top, spacing: 8) {
                severityIcon
                    .frame(width: 16, height: 16)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(alert.title)
                            .font(
                                .system(
                                    size: 14,
                                    weight: .semibold
                                )
                            )
                            .lineLimit(1)
                        Spacer()
                        if showCopied {
                            Text("Copied")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                                .transition(.opacity)
                        } else {
                            Text(relativeTime)
                                .font(.system(size: 12))
                                .foregroundStyle(
                                    .tertiary
                                )
                        }
                    }
                    Text(alert.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if !alert.suggestion.isEmpty {
                        Text(alert.suggestion)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopied = false
            }
        }
    }

    @ViewBuilder
    private var severityIcon: some View {
        switch alert.severity {
        case .critical:
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(.red)
        case .warning:
            Image(
                systemName: "exclamationmark.triangle.fill"
            )
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
        let seconds = Date().timeIntervalSince(
            alert.timestamp
        )
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let mins = Int(seconds / 60)
            return "\(mins)m ago"
        } else {
            let hours = Int(seconds / 3600)
            return "\(hours)h ago"
        }
    }
}
