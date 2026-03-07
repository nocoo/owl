import SwiftUI

/// Power section: battery level/health bars, state+cycles two-column row,
/// condition row.
struct PowerSection: View {
    let metrics: SystemMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                L10n.tr(.sectionPower), symbol: "bolt.fill",
                color: OwlSectionColor.power
            )

            let batt = metrics.battery

            // Battery level
            MetricRow(
                L10n.tr(.powerLevel),
                value: batt.level,
                text: String(format: "%.0f%%", batt.level),
                color: owlBatteryColor(batt.level)
            )

            // Health
            MetricRow(
                L10n.tr(.powerHealth),
                value: batt.health,
                text: String(format: "%.0f%%", batt.health),
                color: owlHealthColor(batt.health)
            )

            // State + Cycles — two-column InfoRow style
            TwoColumnInfoRow(
                leftLabel: stateLabel(batt),
                leftValue: timeRemainingText(batt),
                rightLabel: L10n.tr(.powerCycles),
                rightValue: "\(batt.cycleCount)"
            )

            // Condition row
            InfoRow(L10n.tr(.powerCond), value: conditionText(batt))
        }
    }

    private func stateLabel(_ batt: BatteryMetrics) -> String {
        if batt.isCharging { return "⚡ \(L10n.tr(.powerCharging))" }
        if batt.isPluggedIn { return "🔌 \(L10n.tr(.powerPlugged))" }
        return "🔋 \(L10n.tr(.powerBattery))"
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

    private func conditionText(_ batt: BatteryMetrics) -> String {
        switch batt.condition {
        case "Unavailable": return L10n.tr(.powerNA)
        case "Normal":      return L10n.tr(.powerNormal)
        default:            return batt.condition
        }
    }

}
