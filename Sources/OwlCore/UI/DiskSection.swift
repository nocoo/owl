import SwiftUI

/// Disk section: INTR usage bar with used/total, separate Read/Write rows.
struct DiskSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                "Disk", symbol: "internaldrive",
                color: OwlSectionColor.disk
            )

            let disk = metrics.disk

            // Internal storage usage with used/total
            MetricRow(
                "INTR",
                value: disk.usedPercent,
                text: usedText(disk),
                color: thresholdColor(
                    disk.usedPercent, yellow: 75, red: 90
                )
            )

            // Read throughput
            ThroughputRow(
                label: "Read",
                bytesPerSec: disk.readBytesPerSec,
                icon: "arrow.down",
                iconColor: OwlDiskColor.read
            )

            // Write throughput
            ThroughputRow(
                label: "Write",
                bytesPerSec: disk.writeBytesPerSec,
                icon: "arrow.up",
                iconColor: OwlDiskColor.write
            )
        }
    }

    private func usedText(
        _ disk: DiskMetrics
    ) -> String {
        let pct = String(
            format: "%.1f%%", disk.usedPercent
        )
        let used = formatBytes(disk.usedBytes)
        let total = formatBytes(disk.totalBytes)
        return "\(pct), \(used)/\(total)"
    }
}

/// Row showing throughput with a mini bar scaled to a reasonable max.
private struct ThroughputRow: View {
    let label: String
    let bytesPerSec: Double
    let icon: String
    let iconColor: Color

    // Scale bar to 500 MB/s as "full"
    private let maxRate: Double = 500 * 1_048_576

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(OwlFont.throughputLabel)
                .foregroundStyle(.secondary)
                .frame(
                    width: OwlLayout.labelColumnWidth,
                    alignment: .leading
                )

            MiniBar(
                value: min(bytesPerSec, maxRate),
                max: maxRate,
                color: iconColor.opacity(0.7)
            )

            Text(formatThroughput(bytesPerSec))
                .font(OwlFont.throughputValue)
                .foregroundStyle(.secondary)
                .frame(
                    width: OwlLayout.valueColumnWidth,
                    alignment: .trailing
                )
        }
        .frame(height: OwlLayout.metricRowHeight)
    }
}
