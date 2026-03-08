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

            // Available / Total info rows
            InfoRow(
                L10n.tr(.diskAvail),
                value: formatBytes(disk.freeBytes)
            )
            InfoRow(
                L10n.tr(.diskTotal),
                value: formatBytes(disk.totalBytes)
            )
        }
    }
}

/// Two-column throughput row: Read (left) and Write (right), each with
/// a mini bar and value text.
private struct DualThroughputRow: View {
    let readBytesPerSec: Double
    let writeBytesPerSec: Double

    // Scale bars to 500 MB/s as "full"
    private let maxRate: Double = 500 * 1_048_576

    var body: some View {
        HStack(spacing: 0) {
            // Read column
            HStack(spacing: 4) {
                Text(L10n.tr(.diskRead))
                    .font(OwlFont.throughputLabel)
                    .foregroundStyle(.secondary)
                    .frame(
                        width: OwlLayout.labelColumnWidth,
                        alignment: .leading
                    )
                MiniBar(
                    value: min(readBytesPerSec, maxRate),
                    max: maxRate,
                    color: OwlDiskColor.read.opacity(0.7)
                )
                Text(formatThroughput(readBytesPerSec))
                    .font(OwlFont.throughputValue)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Write column
            HStack(spacing: 4) {
                Text(L10n.tr(.diskWrite))
                    .font(OwlFont.throughputLabel)
                    .foregroundStyle(.secondary)
                    .frame(
                        width: OwlLayout.labelColumnWidth,
                        alignment: .leading
                    )
                MiniBar(
                    value: min(writeBytesPerSec, maxRate),
                    max: maxRate,
                    color: OwlDiskColor.write.opacity(0.7)
                )
                Text(formatThroughput(writeBytesPerSec))
                    .font(OwlFont.throughputValue)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: OwlLayout.metricRowHeight)
    }
}
