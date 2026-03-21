import SwiftUI

/// Memory section: used/free bars, key-value info rows, swap.
struct MemorySection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                L10n.tr(.sectionMemory),
                symbol: "memorychip",
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

            // Cache / Avail / PageIn / PageOut — merged 4-column row
            FourColumnInfoRow(
                c1Label: L10n.tr(.memCache),
                c1Value: formatBytes(mem.cached),
                c2Label: L10n.tr(.memAvail),
                c2Value: formatBytes(mem.available),
                c3Label: L10n.tr(.memPageIn),
                c3Value: formatCount(mem.pageins),
                c4Label: L10n.tr(.memPageOut),
                c4Value: formatCount(mem.pageouts)
            )

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
        }
    }

    /// Format a large count to human-readable (e.g. 1.2M, 345K).
    private func formatCount(_ count: UInt64) -> String {
        Self.formatCount(count)
    }

    static func formatCount(_ count: UInt64) -> String {
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

    // MARK: - Clipboard

    /// Format current memory metrics as plain text for clipboard.
    static func clipboardText(_ metrics: SystemMetrics) -> String {
        let mem = metrics.extendedMemory
        var lines: [String] = []
        lines.append(
            "[Memory] Used: \(String(format: "%.1f%%", mem.usedPercent))"
            + " (\(formatBytes(mem.used)) / \(formatBytes(mem.total)))"
        )
        lines.append(
            "Free: \(String(format: "%.1f%%", mem.freePercent))"
            + " | Cache: \(formatBytes(mem.cached))"
            + " | Avail: \(formatBytes(mem.available))"
        )
        lines.append(
            "PageIn: \(formatCount(mem.pageins))"
            + " | PageOut: \(formatCount(mem.pageouts))"
        )
        if mem.swapTotal > 0 {
            lines.append(
                "Swap: \(String(format: "%.1f%%", mem.swapPercent))"
                + " (\(formatBytes(mem.swapUsed)) / \(formatBytes(mem.swapTotal)))"
            )
        }
        return lines.joined(separator: "\n")
    }
}

/// Four-column info row: 4 label-value pairs in a single row.
struct FourColumnInfoRow: View {
    let c1Label: String
    let c1Value: String
    let c2Label: String
    let c2Value: String
    let c3Label: String
    let c3Value: String
    let c4Label: String
    let c4Value: String

    var body: some View {
        HStack(spacing: 0) {
            column(label: c1Label, value: c1Value)
            column(label: c2Label, value: c2Value)
            column(label: c3Label, value: c3Value)
            column(label: c4Label, value: c4Value)
        }
        .frame(height: OwlLayout.infoRowHeight)
    }

    private func column(label: String, value: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(OwlFont.twoColumnText)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(OwlFont.twoColumnText)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
