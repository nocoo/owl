import SwiftUI

/// Power section: battery level/health bars, state with time remaining,
/// condition + cycles + temperature merged on bottom row.
struct PowerSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                "Power", symbol: "bolt.fill", color: .yellow
            )

            let batt = metrics.battery

            // Battery level
            MetricRow(
                "Level",
                value: batt.level,
                text: String(format: "%.0f%%", batt.level),
                color: batteryColor(batt.level)
            )

            // Health
            MetricRow(
                "Health",
                value: batt.health,
                text: String(format: "%.0f%%", batt.health),
                color: healthColor(batt.health)
            )

            // State + time remaining on same row
            stateRow(batt)

            // Bottom row: condition · cycles · temperature
            bottomRow(batt)
        }
    }

    private func stateRow(
        _ batt: BatteryMetrics
    ) -> some View {
        HStack(spacing: 4) {
            Text("")
                .frame(width: 40)
            Image(systemName: chargingIcon(batt))
                .font(.system(size: 8))
                .foregroundStyle(chargingColor(batt))
            Text(batt.stateText)
                .font(
                    .system(size: 9, design: .monospaced)
                )
                .foregroundStyle(.secondary)

            if let mins = batt.timeRemaining, mins > 0 {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(formatTimeRemaining(mins))
                    .font(
                        .system(size: 9, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(height: 14)
    }

    private func bottomRow(
        _ batt: BatteryMetrics
    ) -> some View {
        HStack(spacing: 4) {
            Text("")
                .frame(width: 40)

            let parts = buildBottomParts(batt)
            Text(parts.joined(separator: " · "))
                .font(
                    .system(size: 9, design: .monospaced)
                )
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Spacer()
        }
        .frame(height: 12)
    }

    private func buildBottomParts(
        _ batt: BatteryMetrics
    ) -> [String] {
        var parts: [String] = []

        if batt.condition != "Unavailable" {
            parts.append(batt.condition)
        }

        parts.append("\(batt.cycleCount) cycles")

        if let temp = batt.temperature {
            parts.append(String(format: "%.1f°C", temp))
        }

        return parts
    }

    private func formatTimeRemaining(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%d:%02d", h, m)
    }

    private func batteryColor(_ level: Double) -> Color {
        if level <= 10 { return .red }
        if level <= 20 { return .orange }
        return .green
    }

    private func healthColor(_ health: Double) -> Color {
        if health < 50 { return .red }
        if health < 80 { return .yellow }
        return .green
    }

    private func chargingIcon(
        _ batt: BatteryMetrics
    ) -> String {
        if batt.isCharging { return "bolt.fill" }
        if batt.isPluggedIn { return "powerplug.fill" }
        return "battery.100"
    }

    private func chargingColor(
        _ batt: BatteryMetrics
    ) -> Color {
        if batt.isCharging { return .green }
        if batt.isPluggedIn { return .yellow }
        return .secondary
    }
}
