import SwiftUI

/// CPU section: total usage bar, per-core heatmap, load avg,
/// temperature.
struct CPUSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader("CPU", symbol: "cpu", color: .green)

            // Total CPU
            MetricRow(
                "Total",
                value: metrics.cpuUsage,
                text: totalText,
                color: thresholdColor(metrics.cpuUsage)
            )

            // Per-core heatmap (compact grid)
            if !metrics.perCoreCPU.isEmpty {
                coreHeatmap
            }

            // Load average
            loadAverageRow

            // Active core count info
            if !metrics.perCoreCPU.isEmpty {
                coreCountRow
            }
        }
    }

    private var totalText: String {
        if let temp = metrics.cpuTemperature {
            let pct = String(format: "%.1f%%", metrics.cpuUsage)
            let deg = String(format: "%.0f°C", temp)
            return "\(pct) @ \(deg)"
        }
        return String(format: "%.1f%%", metrics.cpuUsage)
    }

    private var coreHeatmap: some View {
        let cores = metrics.perCoreCPU
        let columns = min(cores.count, 8)
        let gridItems = Array(
            repeating: GridItem(
                .flexible(), spacing: 2
            ),
            count: columns
        )

        return LazyVGrid(
            columns: gridItems, spacing: 2
        ) {
            ForEach(cores) { core in
                RoundedRectangle(cornerRadius: 2)
                    .fill(heatColor(core.usage))
                    .frame(height: 10)
                    .help("Core \(core.id): \(formatPct(core.usage))")
            }
        }
    }

    private var loadAverageRow: some View {
        let load = metrics.loadAverage
        let parts = [load.one, load.five, load.fifteen]
            .map { String(format: "%.2f", $0) }
        let text = parts.joined(separator: " / ")
        return HStack(spacing: 6) {
            Text("Load")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            Text(text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(height: 14)
    }

    private var coreCountRow: some View {
        let count = metrics.perCoreCPU.count
        return HStack(spacing: 6) {
            Text("")
                .frame(width: 40)
            Text("\(count) cores")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(height: 12)
    }

    private func heatColor(_ usage: Double) -> Color {
        if usage >= 80 { return .red.opacity(0.9) }
        if usage >= 60 { return .orange.opacity(0.8) }
        if usage >= 40 { return .yellow.opacity(0.7) }
        if usage >= 20 { return .green.opacity(0.6) }
        return .green.opacity(0.2)
    }

    private func formatPct(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}
