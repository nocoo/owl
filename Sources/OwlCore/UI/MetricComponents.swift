import AppKit
import SwiftUI

// MARK: - CopyableSection Environment

/// Environment key that CopyableSection sets to true after a copy,
/// so child SectionHeaders can show the "Copied" badge.
private struct ShowCopiedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var showCopied: Bool {
        get { self[ShowCopiedKey.self] }
        set { self[ShowCopiedKey.self] = newValue }
    }
}

// MARK: - CopyableSection

/// Wraps any metric section in a tappable button that copies
/// a snapshot of the section's data to the clipboard.
///
/// On click the text is written to `NSPasteboard` and a green
/// "Copied" badge briefly appears in the section header via
/// the `showCopied` environment value.
struct CopyableSection<Content: View>: View {
    let clipboardText: String
    @ViewBuilder let content: () -> Content

    @State private var copied = false
    @State private var isHovered = false

    var body: some View {
        Button(action: copyToClipboard) {
            content()
                .environment(\.showCopied, copied)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(isHovered ? 0.03 : 0))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            clipboardText, forType: .string
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                copied = false
            }
        }
    }
}

// MARK: - SectionHeader

/// Reusable section header with icon, title, and dashed separator.
/// When `showCopied` is true, a green "Copied" label appears at the
/// trailing end of the dashed line as brief visual feedback.
///
/// By default reads the `showCopied` environment value set by
/// ``CopyableSection``, but can also be overridden explicitly.
struct SectionHeader: View {
    let symbol: String
    let title: String
    let color: Color
    private let overrideCopied: Bool?

    @Environment(\.showCopied) private var envCopied

    init(
        _ title: String,
        symbol: String,
        color: Color = .secondary,
        showCopied: Bool? = nil
    ) {
        self.title = title
        self.symbol = symbol
        self.color = color
        self.overrideCopied = showCopied
    }

    private var isCopied: Bool {
        overrideCopied ?? envCopied
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(OwlFont.sectionIcon)
                .foregroundStyle(color)
            Text(title)
                .font(OwlFont.sectionTitle)
                .foregroundStyle(.primary)

            // Dashed separator fills remaining space
            DashedLine()
                .stroke(
                    style: StrokeStyle(
                        lineWidth: 0.5,
                        dash: [3, 2]
                    )
                )
                .foregroundStyle(.quaternary)
                .frame(height: 1)

            if isCopied {
                Text(L10n.tr(.copied))
                    .font(OwlFont.historyCopied)
                    .foregroundStyle(OwlSeverityColor.normal)
                    .transition(.opacity)
            }
        }
        .frame(height: OwlLayout.sectionHeaderHeight)
    }
}

/// A single horizontal dashed line shape.
private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(
            to: CGPoint(x: rect.maxX, y: rect.midY)
        )
        return path
    }
}

/// Horizontal bar showing a value as a percentage.
struct MiniBar: View {
    let value: Double // 0-100
    let maxValue: Double
    let barColor: Color

    init(
        value: Double,
        max maxValue: Double = 100,
        color: Color = OwlPalette.green
    ) {
        self.value = value
        self.maxValue = maxValue
        self.barColor = color
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: fillWidth(in: geo.size.width))
            }
        }
        .frame(height: OwlLayout.miniBarHeight)
        .animation(.easeInOut(duration: 0.6), value: value)
    }

    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        guard maxValue > 0 else { return 0 }
        let ratio = min(max(value / maxValue, 0), 1)
        return totalWidth * CGFloat(ratio)
    }
}

/// A row with label, bar, and value text.
struct MetricRow: View {
    let label: String
    let value: Double
    let maxValue: Double
    let valueText: String
    let barColor: Color

    init(
        _ label: String,
        value: Double,
        max maxValue: Double = 100,
        text: String,
        color: Color = OwlPalette.green
    ) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
        self.valueText = text
        self.barColor = color
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(OwlFont.rowLabel)
                .foregroundStyle(.secondary)
                .frame(
                    width: OwlLayout.labelColumnWidth,
                    alignment: .leading
                )
            MiniBar(
                value: value,
                max: maxValue,
                color: barColor
            )
            Text(valueText)
                .font(OwlFont.miniValue)
                .foregroundStyle(.primary)
                .frame(
                    width: OwlLayout.valueColumnWidth,
                    alignment: .trailing
                )
        }
        .frame(height: OwlLayout.metricRowHeight)
    }
}

/// A simple label + value text row (no bar).
struct InfoRow: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(OwlFont.infoLabel)
                .foregroundStyle(.secondary)
                .frame(
                    width: OwlLayout.labelColumnWidth,
                    alignment: .leading
                )
            Text(value)
                .font(OwlFont.infoValue)
                .foregroundStyle(.tertiary)
        }
        .frame(height: OwlLayout.infoRowHeight)
    }
}

/// Color for a percentage value based on thresholds.
func thresholdColor(
    _ value: Double,
    yellow: Double = 50,
    red: Double = 80
) -> Color {
    owlThresholdColor(value, yellow: yellow, red: red)
}

/// Format bytes to human-readable string (GB, MB, etc.)
func formatBytes(_ bytes: UInt64) -> String {
    let gb = Double(bytes) / 1_073_741_824
    if gb >= 100 {
        return String(format: "%.0fG", gb)
    }
    if gb >= 10 {
        return String(format: "%.1fG", gb)
    }
    if gb >= 1 {
        return String(format: "%.1f GB", gb)
    }
    let mb = Double(bytes) / 1_048_576
    return String(format: "%.0f MB", mb)
}

/// Format bytes per second to human-readable throughput.
func formatThroughput(_ bytesPerSec: Double) -> String {
    if bytesPerSec >= 1_048_576 {
        return String(
            format: "%.1f MB/s",
            bytesPerSec / 1_048_576
        )
    }
    if bytesPerSec >= 1024 {
        return String(
            format: "%.0f KB/s",
            bytesPerSec / 1024
        )
    }
    return String(format: "%.0f B/s", bytesPerSec)
}
