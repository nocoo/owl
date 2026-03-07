import SwiftUI

/// Color thresholds for a metric gauge.
public struct GaugeThresholds: Sendable {
    public let yellowAt: Double
    public let redAt: Double

    public init(yellowAt: Double, redAt: Double) {
        self.yellowAt = yellowAt
        self.redAt = redAt
    }

    func color(for value: Double) -> Color {
        if value >= redAt {
            return .red
        } else if value >= yellowAt {
            return .yellow
        }
        return .green
    }

    /// Default thresholds for each metric type.
    public static let cpu = GaugeThresholds(yellowAt: 50, redAt: 80)
    public static let memory = GaugeThresholds(yellowAt: 70, redAt: 90)
    public static let temperature = GaugeThresholds(
        yellowAt: 70, redAt: 90
    )
}

/// A compact metric gauge showing label, value, and a mini progress bar.
///
/// Used in SystemOverviewBar to display CPU, Memory, and Temperature.
public struct MetricGauge: View {
    let label: String
    let value: Double
    let maxValue: Double
    let unit: String
    let thresholds: GaugeThresholds

    public init(
        label: String,
        value: Double,
        maxValue: Double = 100,
        unit: String = "%",
        thresholds: GaugeThresholds
    ) {
        self.label = label
        self.value = value
        self.maxValue = maxValue
        self.unit = unit
        self.thresholds = thresholds
    }

    private var fraction: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / maxValue, 0), 1)
    }

    private var barColor: Color {
        thresholds.color(for: value)
    }

    private var displayValue: String {
        if unit == "°C" {
            return String(format: "%.0f%@", value, unit)
        }
        return String(format: "%.0f%@", value, unit)
    }

    public var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(label)
                    .font(OwlFont.gaugeLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(displayValue)
                    .font(OwlFont.gaugeValue)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(
                            width: geometry.size.width * fraction
                        )
                }
            }
            .frame(height: OwlLayout.gaugeBarHeight)
        }
    }
}
