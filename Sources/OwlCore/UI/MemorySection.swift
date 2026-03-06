import SwiftUI

/// Memory section: used, free, swap bars + total/avail text.
struct MemorySection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(
                "Memory", symbol: "memorychip", color: .purple
            )

            let mem = metrics.extendedMemory

            MetricRow(
                "Used",
                value: mem.usedPercent,
                text: String(format: "%.1f%%", mem.usedPercent),
                color: thresholdColor(
                    mem.usedPercent, yellow: 70, red: 90
                )
            )

            MetricRow(
                "Free",
                value: freePercent,
                text: String(format: "%.1f%%", freePercent),
                color: .cyan
            )

            // Swap
            if mem.swapTotal > 0 {
                MetricRow(
                    "Swap",
                    value: mem.swapPercent,
                    text: String(
                        format: "%.1f%%", mem.swapPercent
                    ),
                    color: thresholdColor(
                        mem.swapPercent, yellow: 50, red: 80
                    )
                )
            }

            // Total / Available
            let totalText = formatBytes(mem.total)
            let availText = formatBytes(mem.free)

            HStack(spacing: 6) {
                Text("Total")
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                Text(totalText)
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
            }
            .frame(height: 14)

            HStack(spacing: 6) {
                Text("Avail")
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                Text(availText)
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
            }
            .frame(height: 14)
        }
    }

    private var freePercent: Double {
        let mem = metrics.extendedMemory
        guard mem.total > 0 else { return 0 }
        return Double(mem.free) / Double(mem.total) * 100
    }
}
