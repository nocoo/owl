import SwiftUI

/// Processes section: top 5 processes by CPU with mini bars.
struct ProcessesSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                "Top Processes",
                symbol: "list.number",
                color: OwlSectionColor.processes
            )

            let procs = metrics.topProcesses

            if procs.isEmpty {
                Text("No data")
                    .font(OwlFont.rowValue)
                    .foregroundStyle(.tertiary)
                    .frame(height: OwlLayout.metricRowHeight)
            } else {
                ForEach(procs.prefix(3)) { proc in
                    processRow(proc)
                }
            }
        }
    }

    private func processRow(
        _ proc: ProcessMetric
    ) -> some View {
        HStack(spacing: 6) {
            Text(truncatedName(proc.name))
                .font(OwlFont.processName)
                .foregroundStyle(.primary)
                .frame(
                    width: OwlLayout.processNameWidth,
                    alignment: .leading
                )
                .lineLimit(1)
            MiniBar(
                value: proc.cpuPercent,
                max: 100,
                color: thresholdColor(proc.cpuPercent)
            )
            Text(String(format: "%.1f%%", proc.cpuPercent))
                .font(OwlFont.processValue)
                .foregroundStyle(.secondary)
                .frame(
                    width: OwlLayout.processValueWidth,
                    alignment: .trailing
                )
        }
        .frame(height: OwlLayout.metricRowHeight)
    }

    private func truncatedName(_ name: String) -> String {
        if name.count > 12 {
            return String(name.prefix(11)) + "…"
        }
        return name
    }
}
