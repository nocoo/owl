import SwiftUI

/// Memory section: used/free bars, total, cache+avail merged row, swap.
struct MemorySection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                L10n.tr(.sectionMemory), symbol: "memorychip",
                color: OwlSectionColor.memory
            )

            let mem = metrics.extendedMemory

            // Used bar
            MetricRow(
                L10n.tr(.memUsed),
                value: mem.usedPercent,
                text: String(format: "%.1f%%", mem.usedPercent),
                color: thresholdColor(
                    mem.usedPercent, yellow: 70, red: 90
                )
            )

            // Free bar
            MetricRow(
                L10n.tr(.memFree),
                value: mem.freePercent,
                text: String(format: "%.1f%%", mem.freePercent),
                color: OwlPalette.green
            )

            // Total row
            InfoRow(L10n.tr(.memTotal), value: "\(formatBytes(mem.used)) / \(formatBytes(mem.total))")

            // Cache + Available merged into one two-column row
            if mem.cached > 0 || mem.available > 0 {
                TwoColumnInfoRow(
                    leftLabel: L10n.tr(.memCache),
                    leftValue: formatBytes(mem.cached),
                    rightLabel: L10n.tr(.memAvail),
                    rightValue: formatBytes(mem.available)
                )
            }

            // Swap bar + absolute values
            if mem.swapTotal > 0 {
                MetricRow(
                    L10n.tr(.memSwap),
                    value: mem.swapPercent,
                    text: String(
                        format: "%.1f%%", mem.swapPercent
                    ),
                    color: thresholdColor(
                        mem.swapPercent, yellow: 50, red: 80
                    )
                )

                InfoRow(
                    "",
                    value: "\(formatBytes(mem.swapUsed)) / \(formatBytes(mem.swapTotal))"
                )
            }
        }
    }
}

/// Two-column info row: "Label  Value    Label  Value" in InfoRow-style font.
struct TwoColumnInfoRow: View {
    let leftLabel: String
    let leftValue: String
    let rightLabel: String
    let rightValue: String

    var body: some View {
        HStack(spacing: 0) {
            // Left column
            HStack(spacing: 4) {
                Text(leftLabel)
                    .font(OwlFont.twoColumnText)
                    .foregroundStyle(.tertiary)
                Text(leftValue)
                    .font(OwlFont.twoColumnText)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right column
            HStack(spacing: 4) {
                Text(rightLabel)
                    .font(OwlFont.twoColumnText)
                    .foregroundStyle(.tertiary)
                Text(rightValue)
                    .font(OwlFont.twoColumnText)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: OwlLayout.infoRowHeight)
    }
}
