import SwiftUI

/// Processes section: top 5 processes by resident memory with mini bars.
struct MemoryProcessesSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                L10n.tr(.sectionTopMemory),
                symbol: "list.number",
                color: OwlSectionColor.memory
            )

            let procs = metrics.topMemoryProcesses

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
        _ proc: ProcessMemoryMetric
    ) -> some View {
        let mb = Double(proc.memoryBytes) / 1_048_576
        // Scale bar relative to 4 GB (reasonable visual max)
        let barPercent = min(mb / 4096.0, 1.0) * 100.0
        return HStack(spacing: 6) {
            Text(truncatedName(proc.name))
                .font(OwlFont.processName)
                .foregroundStyle(.primary)
                .frame(
                    width: OwlLayout.processNameWidth,
                    alignment: .leading
                )
                .lineLimit(1)
            MiniBar(
                value: barPercent,
                max: 100,
                color: memoryColor(mb)
            )
            Text(formatMemory(proc.memoryBytes))
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
            return String(name.prefix(11)) + "\u{2026}"
        }
        return name
    }

    private func memoryColor(_ mb: Double) -> Color {
        if mb >= 2048 { return OwlPalette.red }
        if mb >= 512 { return OwlPalette.amber }
        return OwlPalette.purple
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    // MARK: - Clipboard

    /// Format current top memory processes as plain text for clipboard.
    static func clipboardText(_ m: SystemMetrics) -> String {
        let procs = m.topMemoryProcesses
        guard !procs.isEmpty else {
            return "[Top Memory] No data"
        }
        var lines: [String] = ["[Top Memory]"]
        for (i, proc) in procs.prefix(3).enumerated() {
            let mb = Double(proc.memoryBytes) / 1_048_576
            let text: String
            if mb >= 1024 {
                text = String(
                    format: "%.1f GB", mb / 1024
                )
            } else {
                text = String(format: "%.0f MB", mb)
            }
            lines.append(
                "\(i + 1). \(proc.name)"
                + " \(text)"
                + " (pid \(proc.id))"
            )
        }
        return lines.joined(separator: "\n")
    }
}
