import SwiftUI

/// Power section: battery level/health bars, state+cycles two-column row,
/// condition row.
struct PowerSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                "Power", symbol: "bolt.fill",
                color: OwlSectionColor.power
            )

            let batt = metrics.battery

            // Battery level
            MetricRow(
                "Level",
                value: batt.level,
                text: String(format: "%.0f%%", batt.level),
                color: owlBatteryColor(batt.level)
            )

            // Health
            MetricRow(
                "Health",
                value: batt.health,
                text: String(format: "%.0f%%", batt.health),
                color: owlHealthColor(batt.health)
            )

            // State + Cycles — two-column InfoRow style
            TwoColumnInfoRow(
                leftLabel: stateLabel(batt),
                leftValue: timeRemainingText(batt),
                rightLabel: "Cycles",
                rightValue: "\(batt.cycleCount)"
            )

            // Condition row
            let condText = batt.condition == "Unavailable"
                ? "N/A" : batt.condition
            InfoRow("Cond", value: condText)
        }
    }

    private func stateLabel(_ batt: BatteryMetrics) -> String {
        if batt.isCharging { return "⚡ Charging" }
        if batt.isPluggedIn { return "🔌 Plugged" }
        return "🔋 Battery"
    }

    private func timeRemainingText(_ batt: BatteryMetrics) -> String {
        if let mins = batt.timeRemaining, mins > 0 {
            return formatTimeRemaining(mins)
        }
        return ""
    }

    private func formatTimeRemaining(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%d:%02d", h, m)
    }

}
