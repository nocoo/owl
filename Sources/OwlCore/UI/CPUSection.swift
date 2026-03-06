import SwiftUI

/// CPU section: total usage bar, top 3 busy cores, load avg with P+E.
struct CPUSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader("CPU", symbol: "cpu", color: .green)

            // Total CPU
            MetricRow(
                "Total",
                value: metrics.cpuUsage,
                text: totalText,
                color: thresholdColor(metrics.cpuUsage)
            )

            // Top 3 busiest cores
            if !metrics.perCoreCPU.isEmpty {
                let topCores = metrics.perCoreCPU
                    .sorted { $0.usage > $1.usage }
                    .prefix(3)
                ForEach(Array(topCores)) { core in
                    MetricRow(
                        "Core\(core.id)",
                        value: core.usage,
                        text: String(
                            format: "%.1f%%", core.usage
                        ),
                        color: thresholdColor(core.usage)
                    )
                }
            }

            // Load average + P+E core breakdown
            loadAverageRow
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

    private var loadAverageRow: some View {
        let load = metrics.loadAverage
        let parts = [load.one, load.five, load.fifteen]
            .map { String(format: "%.2f", $0) }
        let text = parts.joined(separator: " / ")
        let pCores = load.performanceCores
        let eCores = load.efficiencyCores
        return HStack(spacing: 4) {
            Text("Load")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            Text(text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            if pCores > 0 || eCores > 0 {
                Spacer()
                Text("\(pCores)P+\(eCores)E")
                    .font(
                        .system(size: 9, design: .monospaced)
                    )
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 14)
    }
}
