import SwiftUI

/// Network section: download/upload throughput display.
struct NetworkSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(
                "Network", symbol: "network", color: .blue
            )

            let net = metrics.network

            // Download
            HStack(spacing: 6) {
                Text("Down")
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                Image(systemName: "arrow.down")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
                Text(formatThroughput(net.bytesInPerSec))
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.primary)
            }
            .frame(height: 14)

            // Upload
            HStack(spacing: 6) {
                Text("Up")
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                Image(systemName: "arrow.up")
                    .font(.system(size: 8))
                    .foregroundStyle(.red)
                Text(formatThroughput(net.bytesOutPerSec))
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.primary)
            }
            .frame(height: 14)
        }
    }
}
