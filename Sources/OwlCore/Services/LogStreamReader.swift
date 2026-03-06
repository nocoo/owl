import Foundation

/// Reads the macOS unified log stream via `/usr/bin/log stream --style ndjson`.
///
/// Spawns a subprocess, reads stdout line-by-line, parses each line as a LogEntry,
/// and exposes the results as an AsyncStream.
///
/// Usage:
/// ```swift
/// let reader = LogStreamReader(predicate: PredicateBuilder.buildAll())
/// await reader.start()
/// for await entry in await reader.entries {
///     // process entry
/// }
/// ```
public actor LogStreamReader {

    /// Lifecycle state of the reader.
    public enum State: Sendable, Equatable {
        case idle
        case running
        case stopped
        case failed(String)
    }

    // MARK: - Properties

    public private(set) var state: State = .idle

    private let predicate: String
    private let processFactory: LogProcessFactory
    private var currentProcess: (any LogProcess)?
    private var readTask: Task<Void, Never>?
    private var entryContinuation: AsyncStream<LogEntry>.Continuation?
    private var _entries: AsyncStream<LogEntry>?

    /// The async stream of parsed log entries.
    /// Only valid after `start()` is called.
    public var entries: AsyncStream<LogEntry> {
        _entries ?? AsyncStream { $0.finish() }
    }

    // MARK: - Init

    /// Create a LogStreamReader.
    /// - Parameters:
    ///   - predicate: The predicate string for `log stream --predicate`.
    ///     Defaults to all patterns.
    ///   - processFactory: Factory to create the subprocess. Defaults to
    ///     `RealProcessFactory` for production use.
    public init(
        predicate: String = PredicateBuilder.buildAll(),
        processFactory: LogProcessFactory = RealProcessFactory()
    ) {
        self.predicate = predicate
        self.processFactory = processFactory
    }

    // MARK: - Lifecycle

    /// Start the log stream reader. Spawns the subprocess and begins reading.
    public func start() {
        guard state == .idle || state == .stopped else { return }
        // Also allow restart from failed state
        if case .failed = state {
            // Allow restart
        } else if state != .idle && state != .stopped {
            return
        }

        let stream = AsyncStream<LogEntry> { continuation in
            self.entryContinuation = continuation
        }
        _entries = stream

        let process = processFactory.makeProcess()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = [
            "stream",
            "--style", "ndjson",
            "--predicate", predicate
        ]

        // Get the pipe from the process (factory sets it up)
        let pipe: Pipe
        if let existingPipe = process.standardOutput as? Pipe {
            pipe = existingPipe
        } else {
            let newPipe = Pipe()
            process.standardOutput = newPipe
            pipe = newPipe
        }

        currentProcess = process
        state = .running

        do {
            try process.launch()
        } catch {
            state = .failed(error.localizedDescription)
            entryContinuation?.finish()
            return
        }

        // Start reading lines in a detached task (non-actor-isolated)
        let fileHandle = pipe.fileHandleForReading
        let continuation = entryContinuation
        readTask = Task.detached {
            Self.readLines(
                from: fileHandle,
                continuation: continuation
            )
        }
    }

    /// Stop the log stream reader. Terminates the subprocess and cleans up.
    public func stop() {
        guard state == .running else { return }
        readTask?.cancel()
        readTask = nil
        currentProcess?.terminate()
        currentProcess = nil
        entryContinuation?.finish()
        entryContinuation = nil
        state = .stopped
    }

    // MARK: - Line reading (static, runs outside actor)

    /// Read lines from the file handle and yield parsed LogEntry values.
    /// This is a static method to avoid actor isolation — it runs on a
    /// detached task and communicates via the continuation.
    private static func readLines(
        from fileHandle: FileHandle,
        continuation: AsyncStream<LogEntry>.Continuation?
    ) {
        guard let continuation else { return }

        // Use synchronous blocking read in a detached task.
        // availableData blocks until data arrives or EOF.
        while true {
            let data = fileHandle.availableData
            guard !data.isEmpty else {
                // EOF — pipe closed
                break
            }

            guard let text = String(data: data, encoding: .utf8) else {
                continue
            }

            let lines = text.components(separatedBy: "\n")
            for line in lines {
                do {
                    if let entry = try LogEntry.fromLine(line) {
                        continuation.yield(entry)
                    }
                } catch {
                    // Skip invalid lines (malformed JSON, etc.)
                    continue
                }
            }
        }

        continuation.finish()
    }
}
