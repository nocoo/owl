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

            // Merge log entries with a periodic flush signal so that
            // entries are never stuck in the buffer during low-traffic
            // periods. Without this, the 250ms threshold only triggers
            // when the *next* entry arrives.
            let merged = Self.mergedEntryStream(
                entries: await reader.entries,
                flushInterval: .milliseconds(250)
            )

            for await event in merged {
                switch event {
                case .entry(let entry):
                    batch.append(entry)
                    guard batch.count >= 64 else { continue }
                case .flush:
                    guard !batch.isEmpty else { continue }
                    let elapsed = ContinuousClock.now - lastFlush
                    guard elapsed >= .milliseconds(200) else {
                        continue
                    }
                }

                let alerts = await pipeline.processBatch(batch)
                batch.removeAll(keepingCapacity: true)
                lastFlush = ContinuousClock.now
                self.deliverAlerts(alerts)
            }

            if !batch.isEmpty {
                let alerts = await pipeline.processBatch(batch)
                self.deliverAlerts(alerts)
            }
        }
    }

    /// Events for the merged log-entry + flush-timer stream.
    private enum EngineEvent: Sendable {
        case entry(LogEntry)
        case flush
    }

    /// Merge a log entry stream with a periodic flush timer into
    /// a single `AsyncStream<EngineEvent>`.
    private static func mergedEntryStream(
        entries: AsyncStream<LogEntry>,
        flushInterval: Duration
    ) -> AsyncStream<EngineEvent> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    // Child 1: forward log entries
                    group.addTask {
                        for await entry in entries {
                            continuation.yield(.entry(entry))
                        }
                    }
                    // Child 2: periodic flush signal
                    group.addTask {
                        while !Task.isCancelled {
                            try? await Task.sleep(
                                for: flushInterval
                            )
                            continuation.yield(.flush)
                        }
                    }
                    // Wait for entries to finish (EOF / cancel)
                    await group.next()
                    group.cancelAll()
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
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
        restartMetricsLoop(samplingMode: .background)
    }

    func restartMetricsLoop(
        samplingMode: MetricsSamplingMode,
        refreshImmediately: Bool = false
    ) {
        metricsTask?.cancel()
        let interval = SystemMetricsPoller.interval(
            for: samplingMode
        )
        let updateIntervalNanoseconds = UInt64(
            interval * 1_000_000_000
        )
        let pipeline = self.pipeline
        metricsTask = Task {
            // start() is idempotent - safe to call multiple times
            await metricsPoller.start()
            await metricsPoller.setSamplingMode(samplingMode)

            if refreshImmediately {
                await metricsPoller.pollOnce()
                let metrics = await metricsPoller.currentMetrics
                // Feed metrics to detection pipeline (always, regardless of popover)
                let alerts = await pipeline.processMetrics(metrics)
                self.deliverAlerts(alerts)
                if self.isPopoverVisible {
                    appState.updateMetrics(metrics)
                }
            }

            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: updateIntervalNanoseconds
                )
                guard !Task.isCancelled else { break }
                await metricsPoller.pollOnce()
                let metrics = await metricsPoller.currentMetrics
                // Feed metrics to detection pipeline (always, regardless of popover)
                let alerts = await pipeline.processMetrics(metrics)
                self.deliverAlerts(alerts)
                if self.isPopoverVisible {
                    appState.updateMetrics(metrics)
                }
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
