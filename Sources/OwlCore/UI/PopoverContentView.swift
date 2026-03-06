import SwiftUI

/// Root SwiftUI view for the popover.
///
/// Two-column system dashboard (~580px wide) with active alerts
/// at the top, CPU/Disk/Processes on the left, and
/// Memory/Power/Network on the right.
public struct PopoverContentView: View {
    @ObservedObject var appState: AppState

    let onSettings: () -> Void
    let onQuit: () -> Void

    public init(
        appState: AppState,
        onSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.appState = appState
        self.onSettings = onSettings
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Active alerts at top (full width)
            if !appState.activeAlerts.isEmpty {
                ActiveAlertsSection(
                    alerts: appState.activeAlerts
                )
                .padding(.vertical, 4)

                Divider()
            }

            // Two-column metrics dashboard
            ScrollView {
                metricsGrid
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }

            Divider()

            BottomBar(
                onSettings: onSettings,
                onQuit: onQuit
            )
        }
        .frame(width: 580)
        .background(.ultraThinMaterial)
    }

    private var metricsGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            // Left column: CPU, Disk, Processes
            VStack(alignment: .leading, spacing: 12) {
                CPUSection(metrics: appState.metrics)
                DiskSection(metrics: appState.metrics)
                ProcessesSection(metrics: appState.metrics)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right column: Memory, Power, Network
            VStack(alignment: .leading, spacing: 12) {
                MemorySection(metrics: appState.metrics)
                PowerSection(metrics: appState.metrics)
                NetworkSection(metrics: appState.metrics)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
