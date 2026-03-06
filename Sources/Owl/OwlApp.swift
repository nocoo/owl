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
            withLength: NSStatusItem.squareLength
        )

        guard let button = statusItem?.button else { return }

        let config = NSImage.SymbolConfiguration(
            pointSize: 16, weight: .medium
        )
        if let source = NSImage(
            systemSymbolName: "bird",
            accessibilityDescription: "Owl"
        )?.withSymbolConfiguration(config),
            let image = source.copy() as? NSImage {
            image.isTemplate = true
            button.image = image
        }

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
            return
        }

        let settingsView = SettingsView(
            viewModel: settingsViewModel,
            appState: appState,
            appIcon: Self.loadAppIcon()
        )
        let hostingController = NSHostingController(
            rootView: settingsView
        )
        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0, width: 520, height: 480
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Owl Settings"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    static func loadAppIcon() -> NSImage? {
        if let url = Bundle.main.url(
            forResource: "AppIcon", withExtension: "icns"
        ) { return NSImage(contentsOf: url) }
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
        let contentView = PopoverContentView(
            appState: appState,
            onSettings: { [weak self] in self?.openSettings() },
            onQuit: { [weak self] in self?.quitApp() }
        )
        popover.contentViewController = NSHostingController(
            rootView: contentView
        )
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
    }

    func startObserving() {
        appState.$currentSeverity
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] severity in
                self?.updateIcon(severity: severity)
            }
            .store(in: &cancellables)
    }

    func updateIcon(severity: Severity) {
        let iconConfig = StatusItemMapper.config(
            for: severity,
            previousSeverity: appState.previousSeverity
        )

        guard let button = statusItem?.button else { return }

        let useTemplate = iconConfig.colorName == .default

        let sizeConfig = NSImage.SymbolConfiguration(
            pointSize: 16, weight: .medium
        )

        let image: NSImage?
        if useTemplate {
            image = NSImage(
                systemSymbolName: iconConfig.symbolName,
                accessibilityDescription: iconConfig.accessibilityLabel
            )?.withSymbolConfiguration(sizeConfig)
                .flatMap { $0.copy() as? NSImage }
            image?.isTemplate = true
            button.contentTintColor = nil
        } else {
            let colorConfig = NSImage.SymbolConfiguration
                .preferringHierarchical()
                .applying(sizeConfig)
            image = NSImage(
                systemSymbolName: iconConfig.symbolName,
                accessibilityDescription: iconConfig.accessibilityLabel
            )?.withSymbolConfiguration(colorConfig)
                .flatMap { $0.copy() as? NSImage }
            image?.isTemplate = false
            button.contentTintColor = nsColor(
                for: iconConfig.colorName
            )
        }

        button.image = image

        stopPulseAnimation()
        if iconConfig.shouldPulse {
            startPulseAnimation()
        }

        if iconConfig.showRecoveryFlash {
            performRecoveryFlash()
        }
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

        button.contentTintColor = .systemGreen

        recoveryTimer?.invalidate()
        recoveryTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let severity = self.appState.currentSeverity
                let cfg = StatusItemMapper.config(for: severity)
                self.statusItem?.button?.contentTintColor =
                    self.nsColor(for: cfg.colorName)
            }
        }
    }
}
