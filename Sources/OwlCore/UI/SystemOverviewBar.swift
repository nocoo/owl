import SwiftUI

/// Top bar in the popover showing CPU, Memory, and Temperature at a glance.
public struct SystemOverviewBar: View {
    let cpuUsage: Double
    let memoryPressure: Double

    public init(cpuUsage: Double, memoryPressure: Double) {
        self.cpuUsage = cpuUsage
        self.memoryPressure = memoryPressure
    }

    public var body: some View {
        HStack(spacing: 12) {
            MetricGauge(
                label: "CPU",
                value: cpuUsage,
                thresholds: .cpu
            )
            Divider()
                .frame(height: 28)
            MetricGauge(
                label: "MEM",
                value: memoryPressure,
                thresholds: .memory
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
