import SwiftUI

/// Process tab showing system uptime and cumulative process CPU/memory rankings.
public struct ProcessTab: View {
    @State private var stats: ProcessStats?
    @State private var isLoading = false

    private let provider = ProcessStatsProvider()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Uptime header
            uptimeHeader
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 20)

            // Rankings table
            if let stats, !stats.rankings.isEmpty {
                rankingTable(stats.rankings)
            } else if isLoading {
                Spacer()
                ProgressView(L10n.tr(.collectingProcessData))
                    .font(.system(size: 12))
                Spacer()
            } else {
                Spacer()
                Text(L10n.tr(.noData))
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .onAppear { refresh() }
    }

    // MARK: - Uptime header

    @ViewBuilder
    private var uptimeHeader: some View {
        if let stats {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text(L10n.tr(.systemUptime))
                        .font(.system(size: 14, weight: .semibold))
                }

                Text(formatUptime(stats.uptime))
                    .font(.system(size: 16, weight: .medium, design: .monospaced))

                Text(L10n.tr(.bootedAt(formatBootTime(stats.bootTime))))
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        } else {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text(L10n.tr(.systemUptime))
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("—")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
            }
        }
    }

    // MARK: - Rankings table

    @ViewBuilder
    private func rankingTable(_ rankings: [ProcessRanking]) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Table header
                HStack(spacing: 0) {
                    Text(L10n.tr(.tableRank))
                        .frame(width: 24, alignment: .trailing)
                    Text(L10n.tr(.tableProcess))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                    Text(L10n.tr(.tableCPUTime))
                        .frame(width: 70, alignment: .trailing)
                    Text(L10n.tr(.tableMemory))
                        .frame(width: 64, alignment: .trailing)
                    Text(L10n.tr(.tableInstances))
                        .frame(width: 28, alignment: .trailing)
                }
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)

                Divider()
                    .padding(.horizontal, 16)

                // Rows
                ForEach(
                    Array(rankings.enumerated()),
                    id: \.element.id
                ) { index, ranking in
                    rankingRow(index: index + 1, ranking: ranking)
                }
            }
        }
    }

    @ViewBuilder
    private func rankingRow(
        index: Int,
        ranking: ProcessRanking
    ) -> some View {
        HStack(spacing: 0) {
            Text("\(index)")
                .frame(width: 24, alignment: .trailing)
                .foregroundStyle(.tertiary)

            Text(ranking.id)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(ranking.cpuTimeFormatted)
                .frame(width: 70, alignment: .trailing)
                .foregroundStyle(
                    ranking.cpuSeconds >= 3600 ? .primary :
                    ranking.cpuSeconds >= 600 ? .secondary :
                    .tertiary
                )

            Text(ranking.memoryFormatted)
                .frame(width: 64, alignment: .trailing)
                .foregroundStyle(
                    ranking.memoryMB >= 1024 ? .primary :
                    ranking.memoryMB >= 256 ? .secondary :
                    .tertiary
                )

            Text(ranking.instanceCount > 1 ? "×\(ranking.instanceCount)" : "")
                .frame(width: 28, alignment: .trailing)
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.vertical, 3)
        .padding(.horizontal, 16)
        .background(
            index % 2 == 0
                ? Color.primary.opacity(0.03)
                : Color.clear
        )
    }

    // MARK: - Helpers

    private func refresh() {
        isLoading = true
        // Run on background to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let result = provider.fetch()
            DispatchQueue.main.async {
                stats = result
                isLoading = false
            }
        }
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let mins = (total % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(mins)m"
        }
        return "\(hours)h \(mins)m"
    }

    private func formatBootTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
