import SwiftUI

/// Processes section: top 5 processes by CPU with mini bars.
struct ProcessesSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                L10n.tr(.sectionTopProcesses),
                symbol: "list.number",
                color: OwlSectionColor.processes
            )

            let procs = metrics.topProcesses

            if procs.isEmpty {
                Text(L10n.tr(.noData))
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

    // MARK: - Clipboard

    /// Format current top processes as plain text for clipboard.
    static func clipboardText(_ metrics: SystemMetrics) -> String {
        let procs = metrics.topProcesses
        guard !procs.isEmpty else {
            return "[Top Processes] No data"
        }
        var lines: [String] = ["[Top Processes]"]
        for (i, proc) in procs.prefix(3).enumerated() {
            lines.append(
                "\(i + 1). \(proc.name)"
                + " \(String(format: "%.1f%%", proc.cpuPercent))"
                + " (pid \(proc.id))"
            )
        }
        return lines.joined(separator: "\n")
    }
}
