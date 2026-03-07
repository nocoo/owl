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
final class AppDelegate: NSObject, NSApplicationDelegate {

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
    let metricsPoller = SystemMetricsPoller()

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
            setupStatusItem()
            setupPopover()
            setupSettingsWiring()
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
        setStatusTitle(" Normal", on: button)

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
                title: "Settings...",
                action: #selector(openSettings),
                keyEquivalent: ","
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit Owl",
                action: #selector(quitApp),
                keyEquivalent: "q"
            )
        )

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
}

// MARK: - Settings

extension AppDelegate {

    @objc func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            // Center after layout pass completes
            DispatchQueue.main.async { window.center() }
            return
        }

        let settingsView = SettingsView(
            viewModel: settingsViewModel,
            appState: appState,
            appIcon: Self.loadAppIcon(),
            logoImage: Self.loadLogoImage()
        )
        let hostingController = NSHostingController(
            rootView: settingsView
        )
        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0, width: 520, height: 520
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Owl Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
        // Center after hosting controller finishes layout
        DispatchQueue.main.async { window.center() }
    }

    static func loadAppIcon() -> NSImage? {
        if let url = Bundle.main.url(
            forResource: "AppIcon", withExtension: "icns"
        ) { return NSImage(contentsOf: url) }
        return loadLogoImage()
    }

    /// Load owl.png logo from bundle Resources or project root.
    static func loadLogoImage() -> NSImage? {
        // Try bundle Resources first
        if let url = Bundle.main.url(
            forResource: "owl", withExtension: "png"
        ) { return NSImage(contentsOf: url) }
        // Fallback: search near executable (dev builds)
        let base = Bundle.main.executableURL?
            .deletingLastPathComponent()
        let searchDirs = [
            base,
            base?.deletingLastPathComponent()
                .deletingLastPathComponent()
        ]
        for dir in searchDirs {
            if let iconURL = dir?
                .appendingPathComponent("owl.png"),
                let img = NSImage(contentsOf: iconURL) {
                return img
            }
        }
        return nil
    }

    func setupSettingsWiring() {
        settingsViewModel.$detectorStates
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] states in
                self?.applyDetectorStates(states)
            }
            .store(in: &cancellables)

        settingsViewModel.$launchAtLogin
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { enabled in
                Self.setLaunchAtLogin(enabled)
            }
            .store(in: &cancellables)
    }

    func applyInitialDetectorStates() {
        let pipeline = self.pipeline
        let settings = self.appSettings
        Task {
            let ids = await pipeline.detectorIDs
            for id in ids {
                let enabled = settings.isDetectorEnabled(id)
                await pipeline.setEnabled(
                    enabled, forDetectorID: id
                )
            }
        }
    }

    func applyDetectorStates(_ states: [String: Bool]) {
        let pipeline = self.pipeline
        Task {
            for (id, enabled) in states {
                await pipeline.setEnabled(
                    enabled, forDetectorID: id
                )
            }
        }
    }

    static func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            // Launch at login is best-effort
        }
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
            width: 322, height: 696
        )

        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 322, height: 696)
        popover.behavior = .transient
    }

    func startObserving() {
        // React to severity OR alert count changes
        appState.$currentSeverity
            .combineLatest(appState.$activeAlerts)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] severity, alerts in
                self?.updateIcon(
                    severity: severity,
                    alertCount: alerts.count
                )
            }
            .store(in: &cancellables)
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
        setStatusTitle(" \(iconConfig.statusLabel)", on: button)

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
            accessibilityDescription: "Owl"
        )?.withSymbolConfiguration(sizeConfig) else {
            return nil
        }

        // No dot — return the raw SF Symbol so macOS can apply
        // template tinting (auto light/dark menu bar adaptation).
        guard let dotColor else {
            return birdImage
        }

        // With dot — compose onto a canvas (isTemplate will be false
        // for alert states, so baked colors are fine here).
        let canvasSize = NSSize(width: 20, height: 18)
        let tintColor = birdColor

        let composed = NSImage(
            size: canvasSize,
            flipped: false
        ) { rect in
            let birdSize = birdImage.size
            let birdX = (rect.width - birdSize.width) / 2
            let birdY = (rect.height - birdSize.height) / 2
            let birdRect = NSRect(
                x: birdX, y: birdY,
                width: birdSize.width,
                height: birdSize.height
            )

            if let tintColor {
                // Draw the bird with explicit color so we don't
                // need contentTintColor (which taints the title).
                tintColor.set()
                birdImage.draw(
                    in: birdRect,
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1.0
                )
                // Re-draw with source-atop to apply the tint
                // over the already-drawn alpha mask.
                tintColor.setFill()
                birdRect.fill(using: .sourceAtop)
            } else {
                birdImage.draw(in: birdRect)
            }

            let dotSize: CGFloat = 6
            let dotX = rect.width - dotSize - 0.5
            let dotY: CGFloat = 0.5
            let dotRect = NSRect(
                x: dotX, y: dotY,
                width: dotSize, height: dotSize
            )

            // White outline for contrast
            let outlineRect = dotRect.insetBy(
                dx: -1, dy: -1
            )
            NSColor.white.setFill()
            NSBezierPath(
                ovalIn: outlineRect
            ).fill()

            // Colored fill
            self.nsColor(for: dotColor).setFill()
            NSBezierPath(ovalIn: dotRect).fill()

            return true
        }

        return composed
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

// MARK: - Animations

extension AppDelegate {

    func startPulseAnimation() {
        guard let button = statusItem?.button else { return }
        var increasing = false
        pulseTimer = Timer.scheduledTimer(
            withTimeInterval: 0.05,
            repeats: true
        ) { [weak button] _ in
            guard let button else { return }
            let alpha = button.alphaValue
            if alpha <= 0.4 {
                increasing = true
            } else if alpha >= 1.0 {
                increasing = false
            }
            button.alphaValue += increasing ? 0.02 : -0.02
        }
    }

    func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        statusItem?.button?.alphaValue = 1.0
    }

    func performRecoveryFlash() {
        guard let button = statusItem?.button else { return }

        // Flash the bird green by re-composing the icon with
        // green tint — avoids contentTintColor which also
        // tints the title text.
        let severity = appState.currentSeverity
        let alertCount = appState.activeAlerts.count
        let cfg = StatusItemMapper.config(
            for: severity, alertCount: alertCount
        )
        let flashImage = composeBirdIcon(
            symbolName: cfg.symbolName,
            dotColor: cfg.dotColor,
            birdColor: .systemGreen
        )
        flashImage?.isTemplate = false
        button.image = flashImage

        recoveryTimer?.invalidate()
        recoveryTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Restore to current state
                let sev = self.appState.currentSeverity
                let count = self.appState.activeAlerts.count
                self.updateIcon(
                    severity: sev, alertCount: count
                )
            }
        }
    }
}
