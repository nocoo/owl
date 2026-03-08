import SwiftUI

/// Power section: battery level/health bars, state row, cycles row,
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

            // State + Cycles + Condition + Time — four-column
            FourColumnInfoRow(
                c1Label: L10n.tr(.powerState),
                c1Value: stateValue(batt),
                c2Label: L10n.tr(.powerCycles),
                c2Value: "\(batt.cycleCount)",
                c3Label: L10n.tr(.powerCond),
                c3Value: conditionText(batt),
                c4Label: timeRemainingLabel(batt),
                c4Value: timeRemainingValue(batt)
            )
        }
    }

    private func stateValue(_ batt: BatteryMetrics) -> String {
        if batt.isCharging { return "⚡" }
        if batt.isPluggedIn { return "🔌" }
        return "🔋"
    }

    private func timeRemainingLabel(_ batt: BatteryMetrics) -> String {
        guard let mins = batt.timeRemaining, mins > 0 else { return "" }
        return "ETA"
    }

    private func timeRemainingValue(_ batt: BatteryMetrics) -> String {
        guard let mins = batt.timeRemaining, mins > 0 else { return "" }
        return formatTimeRemaining(mins)
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
