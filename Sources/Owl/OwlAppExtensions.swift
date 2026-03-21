import AppKit
import Combine
import OwlCore
import ServiceManagement
import SwiftUI

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
        window.title = L10n.tr(.settingsWindowTitle)
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
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
            base?.deletingLastPathComponent(),
            base?.deletingLastPathComponent()
                .deletingLastPathComponent(),
            base?.deletingLastPathComponent()
                .deletingLastPathComponent()
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

        settingsViewModel.onAppearanceChange = { [weak self] appearance in
            self?.applyAppearance(appearance)
        }
    }

    func bootstrapLocalization() {
        L10n.bootstrap(preference: appSettings.language)
    }

    func setupNotifications() {
        OwlNotifications.requestAuthorization()

        let settings = self.appSettings
        alertManager.onAlertActivated = { alert in
            guard settings.notificationsEnabled else { return }
            OwlNotifications.post(for: alert)
        }
    }

    func applyAppearance(_ appearance: AppAppearance) {
        switch appearance {
        case .auto:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(
                named: .darkAqua
            )
        }
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
