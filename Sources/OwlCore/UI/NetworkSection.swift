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
                L10n.tr(.sectionNetwork),
                symbol: "network",
                color: OwlSectionColor.network
            )

            let net = metrics.network

            // Download row: sparkline + speed
            SpeedRow(
                label: L10n.tr(.netDown),
                bytesPerSec: net.bytesInPerSec,
                history: inHistory,
                color: OwlNetworkColor.download
            )

            // Upload row: sparkline + speed
            SpeedRow(
                label: L10n.tr(.netUp),
                bytesPerSec: net.bytesOutPerSec,
                history: outHistory,
                color: OwlNetworkColor.upload
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
        let ipText = net.localIP.isEmpty ? "" : net.localIP
        return TwoColumnInfoRow(
            leftLabel: interfaceLabel(net.activeInterface),
            leftValue: "",
            rightLabel: L10n.tr(.netIP),
            rightValue: ipText
        )
    }

    private func interfaceLabel(_ name: String) -> String {
        if name.hasPrefix("utun") { return L10n.tr(.netTUN(name)) }
        if name == "en0" { return L10n.tr(.netWiFi) }
        if name.hasPrefix("en") { return L10n.tr(.netEthernet(name)) }
        return name
    }

    // MARK: - Clipboard

    /// Format current network metrics as plain text for clipboard.
    static func clipboardText(_ metrics: SystemMetrics) -> String {
        let net = metrics.network
        var lines: [String] = []
        lines.append(
            "[Network] Down: \(formatThroughput(net.bytesInPerSec))"
            + " | Up: \(formatThroughput(net.bytesOutPerSec))"
        )
        if !net.activeInterface.isEmpty {
            var info = "Interface: \(net.activeInterface)"
            if !net.localIP.isEmpty {
                info += " | IP: \(net.localIP)"
            }
            lines.append(info)
        }
        return lines.joined(separator: "\n")
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
        HStack(spacing: 3) {
            Text(label)
                .font(OwlFont.speedLabel)
                .foregroundStyle(.secondary)
                .frame(
                    width: OwlLayout.labelColumnWidth,
                    alignment: .leading
                )

            // Inline sparkline
            InlineSparkline(
                data: history, color: color
            )
            .frame(height: OwlLayout.sparklineHeight)

            Text(formatThroughput(bytesPerSec))
                .font(OwlFont.speedValue)
                .foregroundStyle(.primary)
                .frame(
                    width: OwlLayout.speedValueWidth,
                    alignment: .trailing
                )
        }
        .frame(height: OwlLayout.metricRowHeight)
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
