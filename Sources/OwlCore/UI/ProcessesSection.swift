import SwiftUI

/// Processes section: top 5 processes by CPU with mini bars.
struct ProcessesSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                "Top Processes",
                symbol: "list.number",
                color: .mint
            )

            let procs = metrics.topProcesses

            if procs.isEmpty {
                Text("No data")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(height: 14)
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
                .font(
                    .system(size: 11, design: .monospaced)
                )
                .foregroundStyle(.primary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)
            MiniBar(
                value: proc.cpuPercent,
                max: 100,
                color: thresholdColor(proc.cpuPercent)
            )
            Text(String(format: "%.1f%%", proc.cpuPercent))
                .font(
                    .system(size: 10, design: .monospaced)
                )
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .frame(height: 14)
    }

    private func truncatedName(_ name: String) -> String {
        if name.count > 12 {
            return String(name.prefix(11)) + "…"
        }
        return name
    }
}
