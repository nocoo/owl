import Foundation

/// Reads the macOS unified log stream via `/usr/bin/log stream --style ndjson`.
///
/// Spawns a subprocess, reads stdout line-by-line, parses each line as a LogEntry,
/// and exposes the results as an AsyncStream. If the process exits unexpectedly,
/// it automatically restarts with exponential backoff.
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
        case restarting
        case failed(String)
    }

    // MARK: - Properties

    public private(set) var state: State = .idle
    public private(set) var restartCount: Int = 0

    private let predicate: String
    private let processFactory: LogProcessFactory
    private let autoRestart: Bool
    private let maxRestarts: Int
    private var backoff: BackoffStrategy
    private var currentProcess: (any LogProcess)?
    private var readTask: Task<Void, Never>?
    private var entryContinuation: AsyncStream<LogEntry>.Continuation?
    private var _entries: AsyncStream<LogEntry>?

    /// The async stream of parsed log entries.
    /// Only valid after `start()` is called. Survives across restarts.
    public var entries: AsyncStream<LogEntry> {
        _entries ?? AsyncStream { $0.finish() }
    }

    // MARK: - Init

    /// Create a LogStreamReader.
    /// - Parameters:
    ///   - predicate: The predicate string for `log stream --predicate`.
    ///   - autoRestart: Whether to automatically restart on unexpected exit.
    ///   - maxRestarts: Maximum number of auto-restarts (0 = unlimited).
    ///   - backoff: Backoff strategy for restart delays.
    ///   - processFactory: Factory to create the subprocess.
    public init(
        predicate: String = PredicateBuilder.buildAll(),
        autoRestart: Bool = true,
        maxRestarts: Int = 0,
        backoff: BackoffStrategy = BackoffStrategy(),
        processFactory: LogProcessFactory = RealProcessFactory()
    ) {
        self.predicate = predicate
        self.autoRestart = autoRestart
        self.maxRestarts = maxRestarts
        self.backoff = backoff
        self.processFactory = processFactory
    }

    // MARK: - Lifecycle

    /// Start the log stream reader. Spawns the subprocess and begins reading.
    public func start() {
        guard canStart else { return }

        // Create the stream only on first start (survives restarts)
        if _entries == nil {
            let stream = AsyncStream<LogEntry> { continuation in
                self.entryContinuation = continuation
            }
            _entries = stream
        }

        launchProcess()
    }

    /// Stop the log stream reader. Terminates the subprocess and cleans up.
    /// No automatic restart will occur after an explicit stop.
    public func stop() {
        guard state == .running || state == .restarting else { return }
        readTask?.cancel()
        readTask = nil
        currentProcess?.terminate()
        currentProcess = nil
        entryContinuation?.finish()
        entryContinuation = nil
        state = .stopped
    }

    // MARK: - Internal restart

    /// Called when the read task detects unexpected EOF.
    func handleProcessExit() {
        guard state == .running else { return }

        currentProcess = nil
        readTask = nil

        guard autoRestart else {
            state = .failed("Process exited unexpectedly")
            entryContinuation?.finish()
            return
        }

        if maxRestarts > 0, restartCount >= maxRestarts {
            state = .failed(
                "Max restarts (\(maxRestarts)) reached"
            )
            entryContinuation?.finish()
            return
        }

        // Schedule restart with backoff
        state = .restarting
        let delay = backoff.nextDelay()
        restartCount += 1

        Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(delay * 1_000_000_000)
            )
            await self?.performRestart()
        }
    }

    private func performRestart() {
        guard state == .restarting else { return }
        launchProcess()
    }

    /// Reset the backoff counter (e.g., after sustained stability).
    public func resetBackoff() {
        backoff.reset()
    }

    // MARK: - Process launch

    private var canStart: Bool {
        switch state {
        case .idle, .stopped:
            return true
        case .failed:
            return true
        default:
            return false
        }
    }

    private func launchProcess() {
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
        readTask = Task.detached { [weak self] in
            Self.readLines(
                from: fileHandle,
                continuation: continuation
            )
            // Reading ended (EOF) — trigger restart if appropriate
            await self?.handleProcessExit()
        }
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
        // Do NOT finish the continuation here — it survives restarts.
        // Continuation is finished only by explicit stop() or max retries.
    }
}
