import Foundation

/// Configuration describing how the Menu Bar icon should appear for a given severity.
///
/// This is a pure value type (no AppKit dependency) so it can be unit-tested
/// in OwlCore. The actual NSStatusItem rendering uses these values in the Owl target.
public struct StatusItemConfig: Equatable, Sendable {

    /// The SF Symbol name to display.
    public let symbolName: String

    /// The accessibility description for the icon.
    public let accessibilityLabel: String

    /// Whether the icon should use a filled variant.
    public let isFilled: Bool

    /// The semantic color name (maps to NSColor in the app).
    public let colorName: StatusIconColor

    /// Whether the icon should pulse (critical state animation).
    public let shouldPulse: Bool

    /// Whether a recovery flash (green) should be shown before this state.
    public let showRecoveryFlash: Bool

    /// The color for the status dot overlay on the bird icon.
    /// nil means no dot should be shown (normal state).
    public let dotColor: StatusIconColor?

    /// The text label shown next to the icon in the menu bar.
    public let statusLabel: String
}

/// Semantic icon color names, mapped to NSColor in the UI layer.
public enum StatusIconColor: String, Sendable, Equatable {
    case `default`  // .secondaryLabelColor
    case blue       // .systemBlue
    case yellow     // .systemYellow
    case red        // .systemRed
    case green      // .systemGreen (recovery flash only)
}

/// Maps Severity to StatusItemConfig for the Menu Bar icon.
public enum StatusItemMapper {

    /// Returns the icon config for a given severity.
    /// - Parameters:
    ///   - severity: The current aggregated severity level.
    ///   - previousSeverity: The previous severity (used to detect recovery).
    ///   - alertCount: Number of active alerts (shown in label for non-normal).
    public static func config(
        for severity: Severity,
        previousSeverity: Severity? = nil,
        alertCount: Int = 0
    ) -> StatusItemConfig {
        let isRecovering = isRecoveryTransition(
            from: previousSeverity, to: severity
        )

        switch severity {
        case .normal:
            return StatusItemConfig(
                symbolName: "bird",
                accessibilityLabel: "Owl — \(L10n.tr(.severityNormal))",
                isFilled: false,
                colorName: isRecovering ? .green : .default,
                shouldPulse: false,
                showRecoveryFlash: isRecovering,
                dotColor: nil,
                statusLabel: ""
            )
        case .info:
            return StatusItemConfig(
                symbolName: "bird",
                accessibilityLabel: "Owl — \(L10n.tr(.severityInfo))",
                isFilled: false,
                colorName: isRecovering ? .green : .blue,
                shouldPulse: false,
                showRecoveryFlash: isRecovering,
                dotColor: .blue,
                statusLabel: alertCount > 0
                    ? "\(L10n.tr(.severityInfo)) (\(alertCount))" : L10n.tr(.severityInfo)
            )
        case .warning:
            return StatusItemConfig(
                symbolName: "bird.fill",
                accessibilityLabel: "Owl — \(L10n.tr(.severityWarning))",
                isFilled: true,
                colorName: .yellow,
                shouldPulse: false,
                showRecoveryFlash: false,
                dotColor: .yellow,
                statusLabel: alertCount > 0
                    ? "\(L10n.tr(.severityWarning)) (\(alertCount))" : L10n.tr(.severityWarning)
            )
        case .critical:
            return StatusItemConfig(
                symbolName: "bird.fill",
                accessibilityLabel: "Owl — \(L10n.tr(.severityCritical))",
                isFilled: true,
                colorName: .red,
                shouldPulse: true,
                showRecoveryFlash: false,
                dotColor: .red,
                statusLabel: alertCount > 0
                    ? "\(L10n.tr(.severityCritical)) (\(alertCount))" : L10n.tr(.severityCritical)
            )
        }
    }

    /// Determines if the severity transition represents a recovery
    /// (going from warning/critical back to normal or info).
    private static func isRecoveryTransition(
        from previous: Severity?,
        to current: Severity
    ) -> Bool {
        guard let previous else { return false }
        let wasElevated = previous == .warning || previous == .critical
        let isNowCalm = current == .normal || current == .info
        return wasElevated && isNowCalm
    }
}
