import AppKit
import SwiftUI

/// Root SwiftUI view for the popover.
///
/// Single-column system dashboard (~280px wide) with app header,
/// active alerts (scrollable if >4), followed by all metrics
/// sections displayed in full without scrolling.
public struct PopoverContentView: View {
    @ObservedObject var appState: AppState

    let logoImage: NSImage?
    let onSettings: () -> Void
    let onQuit: () -> Void

    public init(
        appState: AppState,
        logoImage: NSImage? = nil,
        onSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.appState = appState
        self.logoImage = logoImage
        self.onSettings = onSettings
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(spacing: 0) {
            // App header — pinned at top
            appHeader
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Divider()

            // Scrollable content: metrics + alerts
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    CPUSection(metrics: appState.metrics)
                    MemorySection(metrics: appState.metrics)
                    DiskSection(metrics: appState.metrics)
                    PowerSection(metrics: appState.metrics)
                    TemperatureSection(
                        sensors: appState.metrics.temperatures
                    )
                    NetworkSection(
                        metrics: appState.metrics,
                        inHistory: appState.networkInHistory,
                        outHistory: appState.networkOutHistory
                    )
                    ProcessesSection(metrics: appState.metrics)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // Active alerts inside scroll area
                if !appState.activeAlerts.isEmpty {
                    Divider()

                    ActiveAlertsSection(
                        alerts: appState.activeAlerts
                    )
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Bottom bar — pinned at bottom
            BottomBar(
                onSettings: onSettings,
                onQuit: onQuit
            )
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }

    private var appHeader: some View {
        HStack(spacing: 8) {
            if let logoImage {
                Image(nsImage: logoImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: "bird.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }

            Text("Owl")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            // Status dot
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusColor: Color {
        switch appState.currentSeverity {
        case .normal: return .green
        case .info: return .blue
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    private var statusText: String {
        switch appState.currentSeverity {
        case .normal: return "Normal"
        case .info: return "Info"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}
