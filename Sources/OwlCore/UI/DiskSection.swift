import SwiftUI

/// Disk section: usage bar + read/write throughput rows.
struct DiskSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(
                "Disk", symbol: "internaldrive", color: .orange
            )

            let disk = metrics.disk

            MetricRow(
                "Used",
                value: disk.usedPercent,
                text: usedText(disk),
                color: thresholdColor(
                    disk.usedPercent, yellow: 75, red: 90
                )
            )

            // Free space
            HStack(spacing: 6) {
                Text("Free")
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                Text(formatBytes(disk.freeBytes))
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
            }
            .frame(height: 14)

            // Read throughput
            HStack(spacing: 6) {
                Text("Read")
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                Image(systemName: "arrow.down")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
                Text(formatThroughput(disk.readBytesPerSec))
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
            }
            .frame(height: 14)

            // Write throughput
            HStack(spacing: 6) {
                Text("Write")
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                Image(systemName: "arrow.up")
                    .font(.system(size: 8))
                    .foregroundStyle(.red)
                Text(formatThroughput(disk.writeBytesPerSec))
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
            }
            .frame(height: 14)
        }
    }

    private func usedText(
        _ disk: DiskMetrics
    ) -> String {
        let used = formatBytes(disk.usedBytes)
        let total = formatBytes(disk.totalBytes)
        return "\(used) / \(total)"
    }
}
