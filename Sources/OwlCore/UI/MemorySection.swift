import SwiftUI

/// Memory section: used/free bars, total, cached, available, swap.
struct MemorySection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                "Memory", symbol: "memorychip", color: .purple
            )

            let mem = metrics.extendedMemory

            // Used bar
            MetricRow(
                "Used",
                value: mem.usedPercent,
                text: String(format: "%.1f%%", mem.usedPercent),
                color: thresholdColor(
                    mem.usedPercent, yellow: 70, red: 90
                )
            )

            // Free bar
            MetricRow(
                "Free",
                value: mem.freePercent,
                text: String(format: "%.1f%%", mem.freePercent),
                color: .green
            )

            // Total row
            InfoRow("Total", value: "\(formatBytes(mem.used)) / \(formatBytes(mem.total))")

            // Cached row
            if mem.cached > 0 {
                InfoRow("Cache", value: formatBytes(mem.cached))
            }

            // Available row
            if mem.available > 0 {
                InfoRow("Avail", value: formatBytes(mem.available))
            }

            // Swap bar + absolute values
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

                InfoRow(
                    "",
                    value: "\(formatBytes(mem.swapUsed)) / \(formatBytes(mem.swapTotal))"
                )
            }
        }
    }
}
