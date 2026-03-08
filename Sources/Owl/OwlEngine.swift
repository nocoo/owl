import Foundation
import OwlCore

// MARK: - Engine

extension AppDelegate {

    func startEngine() {
        let reader = LogStreamReader()
        self.reader = reader
        startLogProcessing(reader: reader)
        startTickLoop()
        startMetricsLoop()
    }

    func deliverAlerts(_ alerts: [OwlCore.Alert]) {
        guard !alerts.isEmpty else { return }
        for alert in alerts {
            alertManager.receive(alert)
        }
        appState.updateAlerts(
            active: alertManager.activeAlerts,
            history: alertManager.alertHistory,
            severity: alertManager.currentSeverity
        )
    }

    private func startLogProcessing(reader: LogStreamReader) {
        let pipeline = self.pipeline

        engineTask = Task {
            await reader.start()

            var batch: [LogEntry] = []
            batch.reserveCapacity(64)
            var lastFlush = ContinuousClock.now

            for await entry in await reader.entries {
                batch.append(entry)

                let now = ContinuousClock.now
                let elapsed = now - lastFlush
                guard batch.count >= 64
                    || elapsed >= .milliseconds(250)
                else {
                    continue
                }

                let alerts = await pipeline.processBatch(batch)
                batch.removeAll(keepingCapacity: true)
                lastFlush = now
                self.deliverAlerts(alerts)
            }

            if !batch.isEmpty {
                let alerts = await pipeline.processBatch(batch)
                self.deliverAlerts(alerts)
            }
        }
    }

    private func startTickLoop() {
        let pipeline = self.pipeline

        tickTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: 1_000_000_000
                )

                let tickAlerts = await pipeline.tick()
                self.deliverAlerts(tickAlerts)
                self.alertManager.performMaintenance(
                    at: Date()
                )

                self.appState.updateAlerts(
                    active: self.alertManager.activeAlerts,
                    history: self.alertManager.alertHistory,
                    severity: self.alertManager.currentSeverity
                )
            }
        }
    }

    private func startMetricsLoop() {
        metricsTask = Task {
            await metricsPoller.start()

            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: 2_000_000_000
                )
                let metrics = await metricsPoller.currentMetrics
                appState.updateMetrics(metrics)
            }
        }
    }

    func stopEngine() {
        engineTask?.cancel()
        tickTask?.cancel()
        metricsTask?.cancel()
        engineTask = nil
        tickTask = nil
        metricsTask = nil

        let reader = self.reader
        self.reader = nil
        Task {
            await reader?.stop()
            await metricsPoller.stop()
        }

        stopPulseAnimation()
        recoveryTimer?.invalidate()
    }
}
