import SwiftUI

/// Reusable section header with icon, title, and dashed separator.
struct SectionHeader: View {
    let symbol: String
    let title: String
    let color: Color

    init(
        _ title: String,
        symbol: String,
        color: Color = .secondary
    ) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .bold))
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
        }
        .frame(height: 14)
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
        color: Color = .green
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
        .frame(height: 8)
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
        color: Color = .green
    ) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
        self.valueText = text
        self.barColor = color
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            MiniBar(
                value: value,
                max: maxValue,
                color: barColor
            )
            Text(valueText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 68, alignment: .trailing)
        }
        .frame(height: 14)
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
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(height: 12)
    }
}

/// Color for a percentage value based on thresholds.
func thresholdColor(
    _ value: Double,
    yellow: Double = 50,
    red: Double = 80
) -> Color {
    if value >= red { return .red }
    if value >= yellow { return .yellow }
    return .green
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
