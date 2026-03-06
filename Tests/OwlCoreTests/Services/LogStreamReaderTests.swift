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

    /// Close the pipe and invoke termination handler.
    func closeAndExit(status: Int32 = 0) {
        mockExitStatus = status
        stdout.fileHandleForWriting.closeFile()
        terminationHandler?(self)
    }
}

/// Factory that returns a mock process.
final class MockProcessFactory: LogProcessFactory {
    let mockProcess = MockLogProcess()

    func makeProcess() -> LogProcess {
        mockProcess
    }
}

// MARK: - Tests

@Suite("LogStreamReader")
struct LogStreamReaderTests {

    // MARK: - Helpers

    private func makeValidLogJSON(
        message: String = "test message",
        process: String = "kernel"
    ) -> String {
        // swiftlint:disable:next line_length
        "{\"traceID\":1,\"eventMessage\":\"\(message)\",\"processID\":0,\"processImagePath\":\"/usr/libexec/\(process)\",\"subsystem\":\"\",\"category\":\"\",\"timestamp\":\"2026-03-06 08:30:44.123456+0800\",\"messageType\":\"Default\"}"
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
            processFactory: factory
        )

        await reader.start()

        #expect(factory.mockProcess.isLaunched)
        #expect(
            factory.mockProcess.executableURL ==
            URL(fileURLWithPath: "/usr/bin/log")
        )
        let args = factory.mockProcess.arguments ?? []
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
        let reader = LogStreamReader(processFactory: factory)

        await reader.start()
        #expect(await reader.state == .running)

        await reader.stop()
    }

    @Test func stopTerminatesProcess() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(processFactory: factory)

        await reader.start()
        await reader.stop()

        #expect(factory.mockProcess.isTerminated)
        #expect(await reader.state == .stopped)
    }

    @Test func doubleStartIsNoOp() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(processFactory: factory)

        await reader.start()
        await reader.start() // should not crash
        #expect(await reader.state == .running)

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
        let reader = LogStreamReader(processFactory: factory)

        await reader.start()

        let stream = await reader.entries
        let json = makeValidLogJSON(message: "hello from kernel")
        factory.mockProcess.writeLine(json)
        factory.mockProcess.closeAndExit()

        var entries: [LogEntry] = []
        for await entry in stream {
            entries.append(entry)
        }

        #expect(entries.count == 1)
        #expect(entries.first?.eventMessage == "hello from kernel")
    }

    @Test func skipsEmptyLines() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(processFactory: factory)

        await reader.start()

        let stream = await reader.entries
        factory.mockProcess.writeLine("")
        factory.mockProcess.writeLine(
            makeValidLogJSON(message: "real entry")
        )
        factory.mockProcess.writeLine("")
        factory.mockProcess.closeAndExit()

        var entries: [LogEntry] = []
        for await entry in stream {
            entries.append(entry)
        }

        #expect(entries.count == 1)
    }

    @Test func skipsInvalidJSON() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(processFactory: factory)

        await reader.start()

        let stream = await reader.entries
        factory.mockProcess.writeLine("not json at all")
        factory.mockProcess.writeLine(
            makeValidLogJSON(message: "valid entry")
        )
        factory.mockProcess.closeAndExit()

        var entries: [LogEntry] = []
        for await entry in stream {
            entries.append(entry)
        }

        #expect(entries.count == 1)
        #expect(entries.first?.eventMessage == "valid entry")
    }

    @Test func readsMultipleEntries() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(processFactory: factory)

        await reader.start()

        let stream = await reader.entries
        for idx in 0..<5 {
            factory.mockProcess.writeLine(
                makeValidLogJSON(message: "msg \(idx)")
            )
        }
        factory.mockProcess.closeAndExit()

        var entries: [LogEntry] = []
        for await entry in stream {
            entries.append(entry)
        }

        #expect(entries.count == 5)
    }

    // MARK: - State tracking

    @Test func stateTransitionsIdleToRunningToStopped() async throws {
        let factory = MockProcessFactory()
        let reader = LogStreamReader(processFactory: factory)

        #expect(await reader.state == .idle)

        await reader.start()
        #expect(await reader.state == .running)

        await reader.stop()
        #expect(await reader.state == .stopped)
    }
}
