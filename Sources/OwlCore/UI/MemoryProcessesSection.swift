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
            // Use the largest process as the bar scale so
            // all bars are relative and visually distinct.
            let maxBytes = procs.first?.memoryBytes ?? 1

            if procs.isEmpty {
                Text(L10n.tr(.noData))
                    .font(OwlFont.rowValue)
                    .foregroundStyle(.tertiary)
                    .frame(height: OwlLayout.metricRowHeight)
            } else {
                ForEach(procs.prefix(3)) { proc in
                    processRow(proc, maxBytes: maxBytes)
                }
            }
        }
    }

    private func processRow(
        _ proc: ProcessMemoryMetric,
        maxBytes: UInt64
    ) -> some View {
        let mb = Double(proc.memoryBytes) / 1_048_576
        let barPercent = Double(proc.memoryBytes)
            / Double(max(maxBytes, 1)) * 100.0
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
            Text(Self.formatMemory(proc.memoryBytes))
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

    // MARK: - Formatting

    /// Human-readable memory string: "1.2 GB" or "345 MB".
    static func formatMemory(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    private func memoryColor(_ mb: Double) -> Color {
        if mb >= 2048 { return OwlPalette.red }
        if mb >= 512 { return OwlPalette.amber }
        return OwlPalette.purple
    }

    // MARK: - Clipboard

    /// Format current top memory processes as plain text for clipboard.
    static func clipboardText(_ metrics: SystemMetrics) -> String {
        let procs = metrics.topMemoryProcesses
        guard !procs.isEmpty else {
            return "[Top Memory] No data"
        }
        var lines: [String] = ["[Top Memory]"]
        for (i, proc) in procs.prefix(3).enumerated() {
            lines.append(
                "\(i + 1). \(proc.name)"
                + " \(formatMemory(proc.memoryBytes))"
                + " (pid \(proc.id))"
            )
        }
        return lines.joined(separator: "\n")
    }
}
