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
                L10n.tr(.sectionTemperature), symbol: "thermometer.medium",
                color: OwlSectionColor.temperature
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
                .frame(height: OwlLayout.infoRowHeight)
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
                .font(OwlFont.miniLabel)
                .foregroundStyle(.tertiary)
                .frame(width: 38, alignment: .leading)
                .lineLimit(1)

            MiniBar(
                value: sensor.celsius,
                max: maxTemp,
                color: owlTempColor(sensor.celsius)
            )

            Text(String(format: "%2.0f°C", sensor.celsius))
                .font(OwlFont.miniValue)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(
                    .easeInOut(duration: 0.6),
                    value: sensor.celsius
                )
        }
        .frame(maxWidth: .infinity)
    }
}
