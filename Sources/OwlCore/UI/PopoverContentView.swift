import AppKit
import SwiftUI

/// Root SwiftUI view for the popover.
///
/// Single-column system dashboard (~280px wide) with app header,
/// active alerts (scrollable if >4), followed by all metrics
/// sections displayed in full without scrolling.
public struct PopoverContentView: View {
    var appState: AppState

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
                .padding(.horizontal, OwlLayout.popoverPaddingH)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Divider()

            // Scrollable content: metrics + alerts
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    CopyableSection(
                        clipboardText: CPUSection.clipboardText(appState.metrics)
                    ) {
                        CPUSection(metrics: appState.metrics)
                    }
                    CopyableSection(
                        clipboardText: MemorySection.clipboardText(appState.metrics)
                    ) {
                        MemorySection(metrics: appState.metrics)
                    }
                    CopyableSection(
                        clipboardText: DiskSection.clipboardText(appState.metrics)
                    ) {
                        DiskSection(metrics: appState.metrics)
                    }
                    CopyableSection(
                        clipboardText: PowerSection.clipboardText(appState.metrics)
                    ) {
                        PowerSection(metrics: appState.metrics)
                    }
                    CopyableSection(
                        clipboardText: TemperatureSection.clipboardText(
                            appState.metrics.temperatures
                        )
                    ) {
                        TemperatureSection(
                            sensors: appState.metrics.temperatures
                        )
                    }
                    CopyableSection(
                        clipboardText: NetworkSection.clipboardText(appState.metrics)
                    ) {
                        NetworkSection(
                            metrics: appState.metrics,
                            inHistory: appState.networkInHistory,
                            outHistory: appState.networkOutHistory
                        )
                    }
                    CopyableSection(
                        clipboardText: ProcessesSection.clipboardText(appState.metrics)
                    ) {
                        ProcessesSection(metrics: appState.metrics)
                    }
                }
                .padding(.horizontal, OwlLayout.popoverPaddingH)
                .padding(.vertical, OwlLayout.popoverPaddingV)

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
        .frame(width: OwlLayout.popoverWidth)
        .background(.ultraThinMaterial)
    }

    private var appHeader: some View {
        HStack(spacing: 8) {
            if let logoImage {
                Image(nsImage: logoImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: OwlLayout.popoverLogoSize,
                        height: OwlLayout.popoverLogoSize
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: "bird.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }

            Text(L10n.tr(.appName))
                .font(OwlFont.appTitle)
                .foregroundStyle(.primary)

            Text("v\(OwlInfo.version)")
                .font(OwlFont.versionBadge)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                )

            Spacer()

            // Status dot
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(OwlFont.statusLabel)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusColor: Color {
        switch appState.currentSeverity {
        case .normal: return OwlSeverityColor.normal
        case .info: return OwlSeverityColor.info
        case .warning: return OwlSeverityColor.warning
        case .critical: return OwlSeverityColor.critical
        }
    }

    private var statusText: String {
        switch appState.currentSeverity {
        case .normal: return L10n.tr(.severityNormal)
        case .info: return L10n.tr(.severityInfo)
        case .warning: return L10n.tr(.severityWarning)
        case .critical: return L10n.tr(.severityCritical)
        }
    }
}
