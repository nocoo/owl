import SwiftUI

// MARK: - Typography

/// Centralized typography tokens for the Owl UI.
///
/// All font definitions live here so that changes propagate
/// across popover and settings views automatically.
enum OwlFont {

    // -- Popover header --
    static let appTitle = Font.system(size: 16, weight: .semibold)
    static let versionBadge = Font.system(
        size: 9, weight: .medium, design: .monospaced
    )
    static let statusLabel = Font.system(size: 12)

    // -- Section headers --
    static let sectionIcon = Font.system(size: 10, weight: .bold)
    static let sectionTitle = Font.system(size: 11, weight: .bold)

    // -- Metric rows --
    static let rowLabel = Font.system(size: 11, design: .monospaced)
    static let rowValue = Font.system(size: 10, design: .monospaced)

    // -- Info rows --
    static let infoLabel = Font.system(size: 11, design: .monospaced)
    static let infoValue = Font.system(size: 9, design: .monospaced)

    // -- Two-column info --
    static let twoColumnText = Font.system(
        size: 9, design: .monospaced
    )

    // -- Core / temperature mini rows --
    static let miniLabel = Font.system(size: 8, design: .monospaced)
    static let miniValue = Font.system(size: 8, design: .monospaced)
    static let coreGroupHeader = Font.system(
        size: 10, weight: .medium, design: .monospaced
    )

    // -- Gauge --
    static let gaugeLabel = Font.system(size: 11, weight: .medium)
    static let gaugeValue = Font.system(
        size: 10, weight: .semibold, design: .monospaced
    )

    // -- Throughput rows --
    static let throughputLabel = Font.system(
        size: 11, design: .monospaced
    )
    static let throughputValue = Font.system(
        size: 9, design: .monospaced
    )

    // -- Sparkline speed rows (same as throughput) --
    static let speedLabel = Font.system(
        size: 11, design: .monospaced
    )
    static let speedValue = Font.system(
        size: 9, design: .monospaced
    )

    // -- Process rows --
    static let processName = Font.system(
        size: 11, design: .monospaced
    )
    static let processValue = Font.system(
        size: 10, design: .monospaced
    )

    // -- Alerts --
    static let alertTitle = Font.system(
        size: 14, weight: .semibold
    )
    static let alertBody = Font.system(size: 12)
    static let alertTimestamp = Font.system(size: 12)
    static let alertSectionHeader = Font.system(
        size: 11, weight: .semibold
    )
    static let alertCountBadge = Font.system(size: 9)

    // -- History rows --
    static let historyTime = Font.system(
        size: 10, design: .monospaced
    )
    static let historyTitle = Font.system(size: 11)
    static let historyCopied = Font.system(size: 9)

    // -- Empty states --
    static let emptyIcon = Font.system(size: 24)
    static let emptyTitle = Font.system(
        size: 13, weight: .medium
    )
    static let emptyBody = Font.system(size: 12)

    // -- Bottom bar --
    static let bottomBarButton = Font.system(size: 12)

    // -- Load average --
    static let loadLabel = Font.system(
        size: 11, design: .monospaced
    )
    static let loadValue = Font.system(
        size: 10, design: .monospaced
    )
    static let loadTopology = Font.system(
        size: 9, design: .monospaced
    )

    // -- Settings --
    static let settingsBody = Font.system(size: 14)
    static let settingsToggleName = Font.system(size: 14)
    static let settingsToggleDescription = Font.system(size: 12)
    static let settingsSectionHeader = Font.system(
        size: 14, weight: .semibold
    )

    // -- Process tab --
    static let processTabHeader = Font.system(
        size: 14, weight: .semibold
    )
    static let processTabUptime = Font.system(
        size: 16, weight: .medium, design: .monospaced
    )
    static let processTabSubtitle = Font.system(size: 12)
    static let processTableHeader = Font.system(
        size: 12, weight: .semibold, design: .monospaced
    )
    static let processTableRow = Font.system(
        size: 12, design: .monospaced
    )

    // -- General tab --
    static let generalTitle = Font.system(
        size: 16, weight: .bold
    )
    static let generalVersion = Font.system(size: 12)
    static let generalLink = Font.system(size: 12)
}

// MARK: - Section Colors

/// Signature accent colors for each popover section.
enum OwlSectionColor {
    static let cpu = Color.green
    static let memory = Color.purple
    static let disk = Color.orange
    static let power = Color.yellow
    static let temperature = Color.orange
    static let network = Color.blue
    static let processes = Color.mint
}

// MARK: - Severity Colors

/// Maps ``Severity`` to SwiftUI colors throughout the app.
enum OwlSeverityColor {
    static let normal = Color.green
    static let info = Color.blue
    static let warning = Color.yellow
    static let critical = Color.red
}

// MARK: - Threshold Helpers

/// Returns a traffic-light color (green → yellow → red) for a
/// percentage value.
func owlThresholdColor(
    _ value: Double,
    yellow: Double = 50,
    red: Double = 80
) -> Color {
    if value >= red { return .red }
    if value >= yellow { return .yellow }
    return .green
}

/// Battery level color: ≤10 red, ≤20 orange, else green.
func owlBatteryColor(_ level: Double) -> Color {
    if level <= 10 { return .red }
    if level <= 20 { return .orange }
    return .green
}

/// Battery health color: <50 red, <80 yellow, else green.
func owlHealthColor(_ health: Double) -> Color {
    if health < 50 { return .red }
    if health < 80 { return .yellow }
    return .green
}

/// Temperature color: <45 green, <70 yellow, <90 orange, ≥90 red.
func owlTempColor(_ celsius: Double) -> Color {
    if celsius >= 90 { return .red }
    if celsius >= 70 { return .orange }
    if celsius >= 45 { return .yellow }
    return .green
}

// MARK: - Disk Throughput Colors

/// Colors for disk read/write indicators.
enum OwlDiskColor {
    static let read = Color.green
    static let write = Color.red
}

// MARK: - Network Sparkline Colors

/// Colors for download/upload sparklines.
enum OwlNetworkColor {
    static let download = Color.green
    static let upload = Color.red
}

// MARK: - Layout Constants

/// Shared layout dimensions used across popover views.
enum OwlLayout {
    /// Popover content width (must match NSPopover.contentSize.width).
    static let popoverWidth: CGFloat = 322

    /// Standard horizontal padding inside the popover.
    static let popoverPaddingH: CGFloat = 12

    /// Standard vertical padding inside the popover scroll area.
    static let popoverPaddingV: CGFloat = 8

    /// Row label column width for MetricRow / InfoRow.
    static let labelColumnWidth: CGFloat = 40

    /// Row value column width for MetricRow.
    static let valueColumnWidth: CGFloat = 68

    /// Process name column width.
    static let processNameWidth: CGFloat = 80

    /// Process value column width.
    static let processValueWidth: CGFloat = 48

    /// Standard row height for metrics.
    static let metricRowHeight: CGFloat = 14

    /// Compact row height for info/mini rows.
    static let infoRowHeight: CGFloat = 12

    /// Section header height.
    static let sectionHeaderHeight: CGFloat = 14

    /// MiniBar height.
    static let miniBarHeight: CGFloat = 8

    /// Gauge bar height.
    static let gaugeBarHeight: CGFloat = 4

    /// Sparkline row height.
    static let sparklineHeight: CGFloat = 12

    /// App header logo size in popover.
    static let popoverLogoSize: CGFloat = 22
}
