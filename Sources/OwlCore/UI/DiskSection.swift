import SwiftUI

/// Disk section: INTR usage bar (percentage only), merged R/W throughput,
/// available/total info rows.
struct DiskSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                L10n.tr(.sectionDisk), symbol: "internaldrive",
                color: OwlSectionColor.disk
            )

            let disk = metrics.disk

            // Internal storage usage — percentage only
            MetricRow(
                L10n.tr(.diskINTR),
                value: disk.usedPercent,
                text: String(
                    format: "%.1f%%", disk.usedPercent
                ),
                color: thresholdColor(
                    disk.usedPercent, yellow: 75, red: 90
                )
            )

            // Read + Write throughput — merged two-column row
            DualThroughputRow(
                readBytesPerSec: disk.readBytesPerSec,
                writeBytesPerSec: disk.writeBytesPerSec
            )

            // Available / Total — two-column info row
            TwoColumnInfoRow(
                leftLabel: L10n.tr(.diskAvail),
                leftValue: formatBytes(disk.freeBytes),
                rightLabel: L10n.tr(.diskTotal),
                rightValue: formatBytes(disk.totalBytes)
            )
        }
    }

    // MARK: - Clipboard

    /// Format current disk metrics as plain text for clipboard.
    static func clipboardText(_ m: SystemMetrics) -> String {
        let disk = m.disk
        var lines: [String] = []
        lines.append(
            "[Disk] Usage: \(String(format: "%.1f%%", disk.usedPercent))"
            + " (\(formatBytes(disk.usedBytes)) / \(formatBytes(disk.totalBytes)))"
        )
        lines.append(
            "Read: \(formatThroughput(disk.readBytesPerSec))"
            + " | Write: \(formatThroughput(disk.writeBytesPerSec))"
        )
        lines.append(
            "Available: \(formatBytes(disk.freeBytes))"
        )
        return lines.joined(separator: "\n")
    }
}

/// Two-column throughput row: Read (left) and Write (right), each with
/// a mini bar and value text. Styled to match TempMiniRow standard.
private struct DualThroughputRow: View {
    let readBytesPerSec: Double
    let writeBytesPerSec: Double

    // Scale bars to 500 MB/s as "full"
    private let maxRate: Double = 500 * 1_048_576

    var body: some View {
        HStack(spacing: 6) {
            // Read column
            halfColumn(
                label: L10n.tr(.diskRead),
                bytes: readBytesPerSec,
                color: OwlDiskColor.read.opacity(0.7)
            )

            // Write column
            halfColumn(
                label: L10n.tr(.diskWrite),
                bytes: writeBytesPerSec,
                color: OwlDiskColor.write.opacity(0.7)
            )
        }
        .frame(height: OwlLayout.infoRowHeight)
    }

    private func halfColumn(
        label: String,
        bytes: Double,
        color: Color
    ) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(OwlFont.miniLabel)
                .foregroundStyle(.tertiary)
                .frame(width: 38, alignment: .leading)
                .lineLimit(1)
            MiniBar(
                value: min(bytes, maxRate),
                max: maxRate,
                color: color
            )
            Text(formatThroughput(bytes))
                .font(OwlFont.miniValue)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(
                    .easeInOut(duration: 0.6),
                    value: bytes
                )
        }
        .frame(maxWidth: .infinity)
    }
}
