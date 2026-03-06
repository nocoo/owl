import SwiftUI

/// Power section: battery level/health bars, charging state,
/// cycle count, temperature.
struct PowerSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

            // Charging state
            HStack(spacing: 6) {
                Text("State")
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                Image(systemName: chargingIcon(batt))
                    .font(.system(size: 9))
                    .foregroundStyle(chargingColor(batt))
                Text(batt.stateText)
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
            }
            .frame(height: 14)

            // Cycle count
            HStack(spacing: 6) {
                Text("Cycle")
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                Text("\(batt.cycleCount)")
                    .font(
                        .system(size: 10, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
            }
            .frame(height: 14)

            // Temperature (if available)
            if let temp = batt.temperature {
                HStack(spacing: 6) {
                    Text("Temp")
                        .font(
                            .system(size: 10, design: .monospaced)
                        )
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
                    Text(String(format: "%.1f°C", temp))
                        .font(
                            .system(size: 10, design: .monospaced)
                        )
                        .foregroundStyle(.secondary)
                }
                .frame(height: 14)
            }

            // Condition
            if batt.condition != "Normal"
                && batt.condition != "Unavailable" {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                    Text(batt.condition)
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
                .frame(height: 14)
            }
        }
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
