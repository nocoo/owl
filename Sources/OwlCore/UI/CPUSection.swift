import SwiftUI

/// CPU section: total usage bar, all cores grouped by P/E (2 per row), load avg.
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

            // All cores grouped by P/E topology
            if !metrics.perCoreCPU.isEmpty {
                let load = metrics.loadAverage
                let pCount = load.performanceCores
                let eCount = load.efficiencyCores
                let sorted = metrics.perCoreCPU.sorted { $0.id < $1.id }

                if pCount > 0 {
                    let pCores = Array(sorted.prefix(pCount))
                    coreGroup(label: "P-Cores", cores: pCores)
                }

                if eCount > 0 {
                    let eCores = Array(sorted.dropFirst(pCount).prefix(eCount))
                    coreGroup(label: "E-Cores", cores: eCores)
                }

                // Fallback: if no P/E topology detected, show all cores
                if pCount == 0 && eCount == 0 {
                    coreGroup(label: "Cores", cores: sorted)
                }
            }

            // Load average
            loadAverageRow
        }
    }

    @ViewBuilder
    private func coreGroup(label: String, cores: [CoreCPUUsage]) -> some View {
        // Group header
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(height: 12)

        // Pairs of cores, 2 per row
        let pairs = stride(from: 0, to: cores.count, by: 2).map { i in
            let end = min(i + 2, cores.count)
            return Array(cores[i..<end])
        }

        ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
            HStack(spacing: 6) {
                ForEach(pair) { core in
                    CoreMiniRow(core: core)
                }
                // If odd core count, fill the empty space
                if pair.count == 1 {
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 12)
        }
    }

    private var totalText: String {
        String(format: "%.1f%%", metrics.cpuUsage)
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
                .font(.system(size: 11, design: .monospaced))
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

// MARK: - Core Mini Row

/// Compact single-core display: "C0" label + tiny bar + percentage.
private struct CoreMiniRow: View {
    let core: CoreCPUUsage

    var body: some View {
        HStack(spacing: 3) {
            Text(String(format: "%2d", core.id))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 14, alignment: .trailing)

            MiniBar(
                value: core.usage,
                color: thresholdColor(core.usage)
            )

            Text(String(format: "%4.0f%%", core.usage))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}
