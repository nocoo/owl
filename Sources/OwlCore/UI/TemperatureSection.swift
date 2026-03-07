import SwiftUI

/// Temperature section: all sensors displayed as mini bars (2 per row),
/// similar to per-core CPU display. Color-mapped by temperature range.
struct TemperatureSection: View {
    let sensors: [TemperatureSensor]

    var body: some View {
        if sensors.isEmpty { return AnyView(EmptyView()) }
        return AnyView(content)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(
                "Temp", symbol: "thermometer.medium",
                color: .orange
            )

            // Pairs of sensors, 2 per row
            let pairs = stride(
                from: 0, to: sensors.count, by: 2
            ).map { i in
                let end = min(i + 2, sensors.count)
                return Array(sensors[i..<end])
            }

            ForEach(
                Array(pairs.enumerated()), id: \.offset
            ) { _, pair in
                HStack(spacing: 6) {
                    ForEach(pair) { sensor in
                        TempMiniRow(sensor: sensor)
                    }
                    if pair.count == 1 {
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 12)
            }
        }
    }
}

// MARK: - Temp Mini Row

/// Compact single-sensor display: label + tiny bar + temperature value.
private struct TempMiniRow: View {
    let sensor: TemperatureSensor

    /// Max temperature for bar scale (110°C).
    private let maxTemp: Double = 110

    var body: some View {
        HStack(spacing: 3) {
            Text(sensor.label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 38, alignment: .leading)
                .lineLimit(1)

            MiniBar(
                value: sensor.celsius,
                max: maxTemp,
                color: tempColor(sensor.celsius)
            )

            Text(String(format: "%2.0f°C", sensor.celsius))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Temperature color thresholds:
/// < 45°C green, 45-70°C yellow, 70-90°C orange, >= 90°C red.
private func tempColor(_ celsius: Double) -> Color {
    if celsius >= 90 { return .red }
    if celsius >= 70 { return .orange }
    if celsius >= 45 { return .yellow }
    return .green
}
