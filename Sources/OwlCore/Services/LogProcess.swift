import Foundation

/// Abstraction over Foundation.Process for testability.
public protocol LogProcess: AnyObject {
    var executableURL: URL? { get set }
    var arguments: [String]? { get set }
    var standardOutput: Any? { get set }
    var terminationHandler: (@Sendable (any LogProcess) -> Void)? { get set }
    func launch() throws
    func terminate()
}

/// Factory for creating LogProcess instances.
public protocol LogProcessFactory: Sendable {
    func makeProcess() -> LogProcess
}

/// Default factory that creates real Foundation.Process instances.
public struct RealProcessFactory: LogProcessFactory {
    public init() {}

    public func makeProcess() -> LogProcess {
        RealLogProcess()
    }
}

/// Wrapper around Foundation.Process that conforms to LogProcess.
final class RealLogProcess: LogProcess, @unchecked Sendable {
    private let process = Process()
    private let pipe = Pipe()

    var executableURL: URL? {
        get { process.executableURL }
        set { process.executableURL = newValue }
    }

    var arguments: [String]? {
        get { process.arguments }
        set { process.arguments = newValue }
    }

    var standardOutput: Any? {
        get { pipe }
        set { process.standardOutput = newValue as? Pipe ?? pipe }
    }

    var terminationHandler: (@Sendable (any LogProcess) -> Void)? {
        didSet {
            if let handler = terminationHandler {
                process.terminationHandler = { [weak self] _ in
                    guard let self else { return }
                    handler(self)
                }
            } else {
                process.terminationHandler = nil
            }
        }
    }

    init() {
        process.standardOutput = pipe
    }

    func launch() throws {
        try process.run()
    }

    func terminate() {
        process.terminate()
    }
}
