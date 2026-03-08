import SwiftUI

/// Memory section: used/free bars, key-value info rows, swap.
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

            // Key-value info rows (unified style)
            InfoRow(
                L10n.tr(.memTotal),
                value: "\(formatBytes(mem.used)) / \(formatBytes(mem.total))"
            )

            if mem.cached > 0 || mem.available > 0 {
                TwoColumnInfoRow(
                    leftLabel: L10n.tr(.memCache),
                    leftValue: formatBytes(mem.cached),
                    rightLabel: L10n.tr(.memAvail),
                    rightValue: formatBytes(mem.available)
                )
            }

            // Swap bar + info rows
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

            // Pageins / Pageouts (cumulative since boot)
            if mem.pageins > 0 || mem.pageouts > 0 {
                TwoColumnInfoRow(
                    leftLabel: L10n.tr(.memPageIn),
                    leftValue: formatCount(mem.pageins),
                    rightLabel: L10n.tr(.memPageOut),
                    rightValue: formatCount(mem.pageouts)
                )
            }
        }
    }

    /// Format a large count to human-readable (e.g. 1.2M, 345K).
    private func formatCount(_ count: UInt64) -> String {
        if count >= 1_000_000 {
            return String(
                format: "%.1fM",
                Double(count) / 1_000_000
            )
        }
        if count >= 1_000 {
            return String(
                format: "%.1fK",
                Double(count) / 1_000
            )
        }
        return "\(count)"
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
