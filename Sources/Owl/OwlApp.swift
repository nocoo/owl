import AppKit
import Combine
import OwlCore
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

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let appState = AppState()

    // Engine components
    private let pipeline = DetectorPipeline()
    private let alertManager = AlertStateManager()
    private let metricsPoller = SystemMetricsPoller()

    // Observation
    private var cancellables = Set<AnyCancellable>()
    private var engineTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var metricsTask: Task<Void, Never>?

    // Animation
    private var pulseTimer: Timer?
    private var recoveryTimer: Timer?

    nonisolated func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        Task { @MainActor in
            setupStatusItem()
            setupPopover()
            startObserving()
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

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        guard let button = statusItem?.button else { return }

        let config = NSImage.SymbolConfiguration(
            pointSize: 16, weight: .medium
        )
        let image = NSImage(
            systemSymbolName: "owl",
            accessibilityDescription: "Owl"
        )?.withSymbolConfiguration(config)
        button.image = image

        button.action = #selector(handleClick(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
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

    private func showContextMenu() {
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

    @objc private func openSettings() {
        // TODO: Phase 4 — open Settings window
    }

    @objc private func quitApp() {
        stopEngine()
        NSApp.terminate(nil)
    }

    // MARK: - Popover

    private func setupPopover() {
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

    // MARK: - Icon Updates (via Combine)

    private func startObserving() {
        appState.$currentSeverity
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] severity in
                self?.updateIcon(severity: severity)
            }
            .store(in: &cancellables)
    }

    private func updateIcon(severity: Severity) {
        let iconConfig = StatusItemMapper.config(
            for: severity,
            previousSeverity: appState.previousSeverity
        )

        guard let button = statusItem?.button else { return }

        let symbolConfig = NSImage.SymbolConfiguration(
            pointSize: 16, weight: .medium
        )
        let image = NSImage(
            systemSymbolName: iconConfig.symbolName,
            accessibilityDescription: iconConfig.accessibilityLabel
        )?.withSymbolConfiguration(symbolConfig)

        button.image = image
        button.contentTintColor = nsColor(for: iconConfig.colorName)

        stopPulseAnimation()
        if iconConfig.shouldPulse {
            startPulseAnimation()
        }

        if iconConfig.showRecoveryFlash {
            performRecoveryFlash()
        }
    }

    private func nsColor(for color: StatusIconColor) -> NSColor {
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

    // MARK: - Animations

    private func startPulseAnimation() {
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

    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        statusItem?.button?.alphaValue = 1.0
    }

    private func performRecoveryFlash() {
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

    // MARK: - Engine

    private func startEngine() {
        let reader = LogStreamReader()
        let pipeline = self.pipeline
        let alertManager = self.alertManager
        let appState = self.appState

        engineTask = Task {
            await reader.start()

            for await entry in await reader.entries {
                let alerts = await pipeline.process(entry)
                for alert in alerts {
                    alertManager.receive(alert)
                }

                appState.updateAlerts(
                    active: alertManager.activeAlerts,
                    history: alertManager.alertHistory,
                    severity: alertManager.currentSeverity
                )
            }
        }

        tickTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                let tickAlerts = await pipeline.tick()
                for alert in tickAlerts {
                    alertManager.receive(alert)
                }
                alertManager.performMaintenance(at: Date())

                appState.updateAlerts(
                    active: alertManager.activeAlerts,
                    history: alertManager.alertHistory,
                    severity: alertManager.currentSeverity
                )
            }
        }

        metricsTask = Task {
            await metricsPoller.start()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let metrics = await metricsPoller.currentMetrics
                appState.updateMetrics(metrics)
            }
        }
    }

    private func stopEngine() {
        engineTask?.cancel()
        tickTask?.cancel()
        metricsTask?.cancel()
        engineTask = nil
        tickTask = nil
        metricsTask = nil

        Task {
            await metricsPoller.stop()
        }

        stopPulseAnimation()
        recoveryTimer?.invalidate()
    }
}
