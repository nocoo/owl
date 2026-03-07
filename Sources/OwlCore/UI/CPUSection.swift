import SwiftUI

/// CPU section: total usage bar, all cores grouped by P/E (2 per row), load avg.
struct CPUSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                L10n.tr(.sectionCPU), symbol: "cpu",
                color: OwlSectionColor.cpu
            )

            // Total CPU
            MetricRow(
                L10n.tr(.cpuTotal),
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
                    coreGroup(label: L10n.tr(.cpuPCores), cores: pCores)
                }

                if eCount > 0 {
                    let eCores = Array(sorted.dropFirst(pCount).prefix(eCount))
                    coreGroup(label: L10n.tr(.cpuECores), cores: eCores)
                }

                // Fallback: if no P/E topology detected, show all cores
                if pCount == 0 && eCount == 0 {
                    coreGroup(label: L10n.tr(.cpuCores), cores: sorted)
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
                .font(OwlFont.coreGroupHeader)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(height: OwlLayout.infoRowHeight)

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
            .frame(height: OwlLayout.infoRowHeight)
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
            Text(L10n.tr(.cpuLoad))
                .font(OwlFont.loadLabel)
                .foregroundStyle(.secondary)
                .frame(
                    width: OwlLayout.labelColumnWidth,
                    alignment: .leading
                )
            Text(text)
                .font(OwlFont.loadValue)
                .foregroundStyle(.secondary)
            if pCores > 0 || eCores > 0 {
                Spacer()
                Text("\(pCores)P+\(eCores)E")
                    .font(OwlFont.loadTopology)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: OwlLayout.metricRowHeight)
    }
}

// MARK: - Core Mini Row

/// Compact single-core display: "C0" label + tiny bar + percentage.
private struct CoreMiniRow: View {
    let core: CoreCPUUsage

    var body: some View {
        HStack(spacing: 3) {
            Text(String(format: "%2d", core.id))
                .font(OwlFont.miniLabel)
                .foregroundStyle(.tertiary)
                .frame(width: 14, alignment: .trailing)

            MiniBar(
                value: core.usage,
                color: thresholdColor(core.usage)
            )

            Text(String(format: "%4.0f%%", core.usage))
                .font(OwlFont.miniValue)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}
