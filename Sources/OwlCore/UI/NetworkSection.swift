import SwiftUI

/// Network section: download/upload each on own row with sparkline + speed,
/// plus interface/IP info at bottom.
struct NetworkSection: View {
    let metrics: SystemMetrics
    var inHistory: [Double] = []
    var outHistory: [Double] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                "Network", symbol: "network", color: .blue
            )

            let net = metrics.network

            // Download row: sparkline + speed
            SpeedRow(
                label: "Down",
                bytesPerSec: net.bytesInPerSec,
                history: inHistory,
                color: .green
            )

            // Upload row: sparkline + speed
            SpeedRow(
                label: "Up",
                bytesPerSec: net.bytesOutPerSec,
                history: outHistory,
                color: .red
            )

            // Interface + IP info
            if !net.activeInterface.isEmpty {
                interfaceRow(net)
            }
        }
    }

    private func interfaceRow(
        _ net: NetworkMetrics
    ) -> some View {
        HStack(spacing: 4) {
            Text("")
                .frame(width: 40)
            Text(interfaceLabel(net.activeInterface))
                .font(
                    .system(size: 9, design: .monospaced)
                )
                .foregroundStyle(.tertiary)
            if !net.localIP.isEmpty {
                Text("·")
                    .foregroundStyle(.quaternary)
                Text(net.localIP)
                    .font(
                        .system(size: 9, design: .monospaced)
                    )
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(height: 12)
    }

    private func interfaceLabel(_ name: String) -> String {
        if name.hasPrefix("utun") { return "TUN \(name)" }
        if name == "en0" { return "Wi-Fi" }
        if name.hasPrefix("en") { return "Ethernet \(name)" }
        return name
    }
}

// MARK: - Speed Row with inline sparkline

/// A row showing label, inline sparkline chart, and current speed.
private struct SpeedRow: View {
    let label: String
    let bytesPerSec: Double
    let history: [Double]
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            // Inline sparkline
            InlineSparkline(
                data: history, color: color
            )
            .frame(height: 12)

            Text(formatThroughput(bytesPerSec))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 68, alignment: .trailing)
        }
        .frame(height: 14)
    }
}

// MARK: - Inline Sparkline

/// Compact sparkline using Canvas, fits within a row.
private struct InlineSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard data.count > 1 else { return }
            let maxVal = data.max() ?? 1
            let ceiling = maxVal > 0 ? maxVal : 1

            // Area fill
            let areaPath = Path { path in
                let stepX = size.width
                    / CGFloat(data.count - 1)
                path.move(
                    to: CGPoint(x: 0, y: size.height)
                )
                for (i, val) in data.enumerated() {
                    let x = stepX * CGFloat(i)
                    let y = size.height
                        - (CGFloat(val / ceiling)
                            * size.height)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(
                    to: CGPoint(
                        x: size.width, y: size.height
                    )
                )
                path.closeSubpath()
            }

            context.fill(
                areaPath,
                with: .linearGradient(
                    Gradient(colors: [
                        color.opacity(0.3),
                        color.opacity(0.05),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(
                        x: 0, y: size.height
                    )
                )
            )

            // Stroke line
            let linePath = Path { path in
                let stepX = size.width
                    / CGFloat(data.count - 1)
                for (i, val) in data.enumerated() {
                    let x = stepX * CGFloat(i)
                    let y = size.height
                        - (CGFloat(val / ceiling)
                            * size.height)
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(
                            to: CGPoint(x: x, y: y)
                        )
                    }
                }
            }

            context.stroke(
                linePath,
                with: .color(color.opacity(0.8)),
                lineWidth: 1
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(.quaternary.opacity(0.2))
        )
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}
