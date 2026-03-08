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

            // State + Cycles + Condition + Wattage — four-column
            FourColumnInfoRow(
                c1Label: L10n.tr(.powerState),
                c1Value: stateValue(batt),
                c2Label: L10n.tr(.powerCycles),
                c2Value: "\(batt.cycleCount)",
                c3Label: L10n.tr(.powerCond),
                c3Value: conditionText(batt),
                c4Label: wattageLabel(batt),
                c4Value: wattageValue(batt)
            )
        }
    }

    private func stateValue(_ batt: BatteryMetrics) -> String {
        if batt.isCharging { return "⚡ \(L10n.tr(.powerCharging))" }
        if batt.isPluggedIn { return "🔌 \(L10n.tr(.powerPlugged))" }
        return "🔋 \(L10n.tr(.powerBattery))"
    }

    private func wattageLabel(_ batt: BatteryMetrics) -> String {
        guard batt.wattage != nil else { return "" }
        return L10n.tr(.powerWatt)
    }

    private func wattageValue(_ batt: BatteryMetrics) -> String {
        guard let w = batt.wattage else { return "" }
        return String(format: "%.1fW", w)
    }

    private func conditionText(_ batt: BatteryMetrics) -> String {
        switch batt.condition {
        case "Unavailable": return L10n.tr(.powerNA)
        case "Normal":      return L10n.tr(.powerNormal)
        default:            return batt.condition
        }
    }

}
