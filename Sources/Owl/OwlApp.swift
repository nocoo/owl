import AppKit
import Combine
import OwlCore
import ServiceManagement
import SwiftUI

@main
struct OwlApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate

        app.run()
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    var statusItem: NSStatusItem?
    let popover = NSPopover()
    let appState = AppState()

    // Settings
    let appSettings = AppSettings()
    lazy var settingsViewModel = SettingsViewModel(
        settings: appSettings
    )
    var settingsWindow: NSWindow?

    // Engine components
    let pipeline = DetectorPipeline()
    let alertManager = AlertStateManager()
    let metricsPoller = SystemMetricsPoller(interval: 10.0)
    var reader: LogStreamReader?
    var isPopoverVisible = false

    // Observation
    var cancellables = Set<AnyCancellable>()
    var engineTask: Task<Void, Never>?
    var tickTask: Task<Void, Never>?
    var metricsTask: Task<Void, Never>?

    // Animation
    var pulseTimer: Timer?
    var recoveryTimer: Timer?

    nonisolated func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        Task { @MainActor in
            bootstrapLocalization()
            applyAppearance(appSettings.appearance)
            setupStatusItem()
            setupPopover()
            setupSettingsWiring()
            setupNotifications()
            startObserving()
            applyInitialDetectorStates()
            startEngine()
        }
    }

    nonisolated func applicationWillTerminate(
        _ notification: Notification
    ) {
        Task { @MainActor in
            stopEngine()
        }
    }

    @objc func quitApp() {
        stopEngine()
        NSApp.terminate(nil)
    }
}

// MARK: - Status Item & Menu

extension AppDelegate {

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        guard let button = statusItem?.button else { return }

        button.image = composeBirdIcon(
            symbolName: "bird", dotColor: nil
        )
        button.image?.isTemplate = true
        button.imagePosition = .imageLeading
        setStatusTitle("", on: button)

        button.action = #selector(handleClick(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
            popover.behavior = .transient
            handlePopoverVisibilityChange(true)

            // Activate the app so the popover's window becomes key
            // immediately — without this, the popover appears with
            // an inactive (translucent) background until clicked.
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?
                .makeKey()
        }
    }

    func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: L10n.tr(.contextSettings),
                action: #selector(openSettings),
                keyEquivalent: ","
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: L10n.tr(.contextQuit),
                action: #selector(quitApp),
                keyEquivalent: "q"
            )
        )

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
}

// MARK: - Popover & Icon

extension AppDelegate {

    func setupPopover() {
        let logo = Self.loadLogoImage()
        let contentView = PopoverContentView(
            appState: appState,
            logoImage: logo,
            onSettings: { [weak self] in self?.openSettings() },
            onQuit: { [weak self] in self?.quitApp() }
        )

        let hosting = NSHostingController(
            rootView: contentView
        )
        // sizingOptions = [] prevents NSHostingController from
        // overriding preferredContentSize based on SwiftUI layout,
        // which would race with NSPopover's positioning logic.
        hosting.sizingOptions = []
        // Set preferred size upfront so NSPopover positions
        // correctly on first open without a layout-driven jump.
        hosting.preferredContentSize = NSSize(
            width: 322, height: 760
        )

        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 322, height: 760)
        popover.behavior = .transient
        popover.delegate = self
    }

    func startObserving() {
        // React to severity OR alert count changes using
        // Observation framework (property-level tracking).
        startObservationLoop()
    }

    private func startObservationLoop() {
        withObservationTracking {
            _ = appState.currentSeverity
            _ = appState.activeAlerts
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateIcon(
                    severity: self.appState.currentSeverity,
                    alertCount: self.appState.activeAlerts.count
                )
                self.startObservationLoop()
            }
        }
    }

    func updateIcon(severity: Severity, alertCount: Int) {
        let iconConfig = StatusItemMapper.config(
            for: severity,
            previousSeverity: appState.previousSeverity,
            alertCount: alertCount
        )

        guard let button = statusItem?.button else { return }

        let hasDot = iconConfig.dotColor != nil
        let birdColor = hasDot
            ? nsColor(for: iconConfig.colorName) : nil
        let image = composeBirdIcon(
            symbolName: iconConfig.symbolName,
            dotColor: iconConfig.dotColor,
            birdColor: birdColor
        )

        // Template mode lets macOS adapt the icon to menu bar
        // appearance.  When a dot is present the image already
        // contains baked-in colors so template must be off.
        // We never set contentTintColor — that would also tint
        // the button title, breaking text legibility.
        image?.isTemplate = !hasDot
        button.contentTintColor = nil

        button.image = image
        let titleText = iconConfig.statusLabel.isEmpty
            ? "" : " \(iconConfig.statusLabel)"
        setStatusTitle(titleText, on: button)

        stopPulseAnimation()
        if iconConfig.shouldPulse {
            startPulseAnimation()
        }

        if iconConfig.showRecoveryFlash {
            performRecoveryFlash()
        }
    }

    /// Return the bird SF Symbol, optionally composed with a colored
    /// status dot.  When no dot is needed the raw symbol is returned
    /// so that `isTemplate = true` works correctly — drawing into a
    /// custom canvas bakes in pixel colors and breaks template
    /// rendering.
    ///
    /// - Parameters:
    ///   - birdColor: When non-nil the bird is drawn in this color
    ///     inside the composed canvas.  This replaces the old
    ///     approach of using `contentTintColor` on the button
    ///     (which also tinted the title text).
    func composeBirdIcon(
        symbolName: String,
        dotColor: StatusIconColor?,
        birdColor: NSColor? = nil
    ) -> NSImage? {
        let sizeConfig = NSImage.SymbolConfiguration(
            pointSize: 14, weight: .medium
        )

        guard let birdImage = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: L10n.tr(.appName)
        )?.withSymbolConfiguration(sizeConfig) else {
            return nil
        }

        // No dot — return the raw SF Symbol so macOS can apply
        // template tinting (auto light/dark menu bar adaptation).
        guard let dotColor else {
            return birdImage
        }

        return composeIconWithDot(
            birdImage: birdImage,
            dotColor: dotColor,
            birdColor: birdColor
        )
    }

    private func composeIconWithDot(
        birdImage: NSImage,
        dotColor: StatusIconColor,
        birdColor: NSColor?
    ) -> NSImage {
        let canvasSize = NSSize(width: 20, height: 18)

        return NSImage(
            size: canvasSize,
            flipped: false
        ) { rect in
            let birdRect = Self.centeredRect(
                for: birdImage.size, in: rect
            )
            Self.drawBird(
                birdImage, in: birdRect, tintColor: birdColor
            )
            Self.drawDot(
                color: self.nsColor(for: dotColor), in: rect
            )
            return true
        }
    }

    private static func centeredRect(
        for imageSize: NSSize, in rect: NSRect
    ) -> NSRect {
        let birdX = (rect.width - imageSize.width) / 2
        let birdY = (rect.height - imageSize.height) / 2
        return NSRect(
            x: birdX,
            y: birdY,
            width: imageSize.width,
            height: imageSize.height
        )
    }

    private static func drawBird(
        _ image: NSImage,
        in rect: NSRect,
        tintColor: NSColor?
    ) {
        if let tintColor {
            tintColor.set()
            image.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
            tintColor.setFill()
            rect.fill(using: .sourceAtop)
        } else {
            image.draw(in: rect)
        }
    }

    private static func drawDot(
        color: NSColor, in rect: NSRect
    ) {
        let dotSize: CGFloat = 6
        let dotX = rect.width - dotSize - 0.5
        let dotY: CGFloat = 0.5
        let dotRect = NSRect(
            x: dotX,
            y: dotY,
            width: dotSize,
            height: dotSize
        )

        // White outline for contrast
        let outlineRect = dotRect.insetBy(dx: -1, dy: -1)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: outlineRect).fill()

        // Colored fill
        color.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }

    func nsColor(for color: StatusIconColor) -> NSColor {
        switch color {
        case .default:
            return .secondaryLabelColor
        case .blue:
            return .systemBlue
        case .yellow:
            return .systemYellow
        case .red:
            return .systemRed
        case .green:
            return .systemGreen
        }
    }

    /// Set the status bar button title.  Using plain `title` +
    /// `font` instead of `attributedTitle` lets macOS automatically
    /// adapt the text color to the menu bar appearance (light text
    /// on dark backgrounds and vice-versa).
    func setStatusTitle(
        _ title: String, on button: NSStatusBarButton
    ) {
        button.font = NSFont.monospacedSystemFont(
            ofSize: 10, weight: .medium
        )
        button.title = title
    }
}

extension AppDelegate {
    func popoverDidClose(_ notification: Notification) {
        handlePopoverVisibilityChange(false)
    }

    private func handlePopoverVisibilityChange(_ visible: Bool) {
        guard isPopoverVisible != visible else { return }
        isPopoverVisible = visible

        restartMetricsLoop(
            samplingMode: visible ? .foreground : .background,
            refreshImmediately: visible
        )
    }
}
