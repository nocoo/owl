import Foundation
import Testing
@testable import OwlCore

// MARK: - Mock process for testing

/// Simulates a `log stream` process by writing lines to a pipe.
final class MockLogProcess: LogProcess, @unchecked Sendable {
    let stdout = Pipe()
    private(set) var isLaunched = false
    private(set) var isTerminated = false
    var terminationHandler: (@Sendable (any LogProcess) -> Void)?
    var mockExitStatus: Int32 = 0

    var executableURL: URL?
    var arguments: [String]?
    var standardOutput: Any? {
        get { stdout }
        // swiftlint:disable:next unused_setter_value
        set { /* ignored for mock */ }
    }

    func launch() throws {
        isLaunched = true
    }

    func terminate() {
        isTerminated = true
    }

    /// Write a line to the mock stdout pipe (simulates log stream output).
    func writeLine(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        stdout.fileHandleForWriting.write(data)
    }

    /// Close the pipe (simulates process exit / EOF).
    func closeStdout() {
        stdout.fileHandleForWriting.closeFile()
    }
}

/// Factory that returns mock processes. Supports multiple launches (restart).
final class MockProcessFactory: @unchecked Sendable, LogProcessFactory {
    private(set) var processes: [MockLogProcess] = []
    private(set) var launchCount = 0

    /// The most recently created mock process.
    var lastProcess: MockLogProcess? { processes.last }

    func makeProcess() -> LogProcess {
        let process = MockLogProcess()
        processes.append(process)
        launchCount += 1
        return process
    }
}

// MARK: - Tests

@Suite("LogStreamReader")
struct LogStreamReaderTests {

    // MARK: - Helpers

    /// Build a valid ndjson line. The message must contain at least
    /// one pre-filter keyword to survive `LogStreamReader.readLines()`
    /// fast-path filtering. Default includes "DarkWake" as keyword.
    private func makeValidLogJSON(
        message: String = "DarkWake test message",
        process: String = "kernel"
    ) -> String {
        let escaped = message.replacingOccurrences(
            of: "\"", with: "\\\""
        )
        // swiftlint:disable:next line_length
        return "{\"traceID\":1,\"eventMessage\":\"\(escaped)\",\"processID\":0,\"processImagePath\":\"/usr/libexec/\(process)\",\"subsystem\":\"\",\"category\":\"\",\"timestamp\":\"2026-03-06 08:30:44.123456+0800\",\"messageType\":\"Default\"}"
    }

    // MARK: - Initialization

    @Test func createsWithDefaultPredicate() async {
        let reader = LogStreamReader()
        #expect(await reader.state == .idle)
    }

    @Test func createsWithCustomPredicate() async {
        let reader = LogStreamReader(
            predicate: "process == 'kernel'"
        )
        #expect(await reader.state == .idle)
    }

    // MARK: - Process arguments

    @Test func configuresProcessCorrectly() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            predicate: "process == 'kernel'",
            autoRestart: false,
            processFactory: factory
        )

        await reader.start()

        let process = factory.lastProcess
        #expect(process?.isLaunched == true)
        #expect(
            process?.executableURL ==
            URL(fileURLWithPath: "/usr/bin/log")
        )
        let args = process?.arguments ?? []
        #expect(args.contains("stream"))
        #expect(args.contains("--style"))
        #expect(args.contains("ndjson"))
        #expect(args.contains("--predicate"))
        #expect(args.contains("process == 'kernel'"))

        await reader.stop()
    }

    // MARK: - Lifecycle

    @Test func startTransitionsToRunning() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            autoRestart: false,
            processFactory: factory
        )

        await reader.start()
        #expect(await reader.state == .running)

        await reader.stop()
    }

    @Test func stopTerminatesProcess() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            autoRestart: false,
            processFactory: factory
        )

        await reader.start()
        await reader.stop()

        #expect(factory.lastProcess?.isTerminated == true)
        #expect(await reader.state == .stopped)
    }

    @Test func doubleStartIsNoOp() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            autoRestart: false,
            processFactory: factory
        )

        await reader.start()
        await reader.start() // should not crash
        #expect(await reader.state == .running)
        #expect(factory.launchCount == 1)

        await reader.stop()
    }

    @Test func stopWhenIdleIsNoOp() async throws {
        let reader = LogStreamReader()
        await reader.stop() // should not crash
        #expect(await reader.state == .idle)
    }

    // MARK: - Line reading

    @Test func readsValidLogEntries() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            autoRestart: false,
            processFactory: factory
        )

        await reader.start()

        let stream = await reader.entries
        let json = makeValidLogJSON(
            message: "DarkWake hello from kernel"
        )
        factory.lastProcess?.writeLine(json)
        factory.lastProcess?.closeStdout()

        var entries: [LogEntry] = []
        for await entry in stream {
            entries.append(entry)
        }

        #expect(entries.count == 1)
        #expect(
            entries.first?.eventMessage ==
            "DarkWake hello from kernel"
        )
    }

    @Test func skipsEmptyLines() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            autoRestart: false,
            processFactory: factory
        )

        await reader.start()

        let stream = await reader.entries
        factory.lastProcess?.writeLine("")
        factory.lastProcess?.writeLine(
            makeValidLogJSON(message: "DarkWake real entry")
        )
        factory.lastProcess?.writeLine("")
        factory.lastProcess?.closeStdout()

        var entries: [LogEntry] = []
        for await entry in stream {
            entries.append(entry)
        }

        #expect(entries.count == 1)
    }

    @Test func skipsInvalidJSON() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            autoRestart: false,
            processFactory: factory
        )

        await reader.start()

        let stream = await reader.entries
        factory.lastProcess?.writeLine("not json at all")
        factory.lastProcess?.writeLine(
            makeValidLogJSON(message: "DarkWake valid entry")
        )
        factory.lastProcess?.closeStdout()

        var entries: [LogEntry] = []
        for await entry in stream {
            entries.append(entry)
        }

        #expect(entries.count == 1)
        #expect(
            entries.first?.eventMessage == "DarkWake valid entry"
        )
    }

    @Test func readsMultipleEntries() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            autoRestart: false,
            processFactory: factory
        )

        await reader.start()

        let stream = await reader.entries
        for idx in 0..<5 {
            factory.lastProcess?.writeLine(
                makeValidLogJSON(
                    message: "DarkWake msg \(idx)"
                )
            )
        }
        factory.lastProcess?.closeStdout()

        var entries: [LogEntry] = []
        for await entry in stream {
            entries.append(entry)
        }

        #expect(entries.count == 5)
    }

    // MARK: - State tracking

    @Test func stateTransitionsIdleToRunningToStopped() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            autoRestart: false,
            processFactory: factory
        )

        #expect(await reader.state == .idle)

        await reader.start()
        #expect(await reader.state == .running)

        await reader.stop()
        #expect(await reader.state == .stopped)
    }

    // MARK: - Auto restart (disabled)

    @Test func noRestartWhenAutoRestartDisabled() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            autoRestart: false,
            processFactory: factory
        )

        await reader.start()

        let stream = await reader.entries
        factory.lastProcess?.closeStdout()

        // Consume all entries (stream should end)
        var entries: [LogEntry] = []
        for await entry in stream {
            entries.append(entry)
        }

        // Give a moment for handleProcessExit to run
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(factory.launchCount == 1)
        let state = await reader.state
        #expect(state == .failed("Process exited unexpectedly"))
    }

    // MARK: - Auto restart (enabled)

    @Test func restartsAfterProcessExit() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            autoRestart: true,
            maxRestarts: 1,
            backoff: BackoffStrategy(
                baseDelay: 0.05,
                maxDelay: 0.1
            ),
            processFactory: factory
        )

        await reader.start()
        #expect(factory.launchCount == 1)

        // Simulate process exit
        factory.lastProcess?.closeStdout()

        // Wait for restart (50ms backoff + some margin)
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(factory.launchCount == 2)
        #expect(await reader.restartCount == 1)
        let state = await reader.state
        #expect(state == .running)

        await reader.stop()
    }

    @Test func stopsAfterMaxRestarts() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            autoRestart: true,
            maxRestarts: 2,
            backoff: BackoffStrategy(
                baseDelay: 0.05,
                maxDelay: 0.1
            ),
            processFactory: factory
        )

        await reader.start()

        // Simulate first crash
        factory.lastProcess?.closeStdout()
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(factory.launchCount == 2)

        // Simulate second crash
        factory.lastProcess?.closeStdout()
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(factory.launchCount == 3)

        // Simulate third crash — should NOT restart
        factory.lastProcess?.closeStdout()
        try await Task.sleep(nanoseconds: 200_000_000)

        let state = await reader.state
        #expect(state == .failed("Max restarts (2) reached"))
        #expect(await reader.restartCount == 2)
    }

    @Test func restartCountIsZeroInitially() async {
        let reader = LogStreamReader()
        #expect(await reader.restartCount == 0)
    }

    @Test func restartCountIncrements() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(
            autoRestart: true,
            maxRestarts: 3,
            backoff: BackoffStrategy(
                baseDelay: 0.05,
                maxDelay: 0.1
            ),
            processFactory: factory
        )

        await reader.start()
        factory.lastProcess?.closeStdout()
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(await reader.restartCount == 1)

        factory.lastProcess?.closeStdout()
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(await reader.restartCount == 2)

        await reader.stop()
    }
}
