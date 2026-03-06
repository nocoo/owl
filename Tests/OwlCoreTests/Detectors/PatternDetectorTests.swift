import Foundation
import Testing
@testable import OwlCore

@Suite("PatternDetector Protocol")
struct PatternDetectorTests {

    // MARK: - Protocol conformance via mock

    /// A minimal mock detector to verify the protocol contract.
    final class MockDetector: PatternDetector {
        let id: String
        var isEnabled: Bool

        var acceptsResult = false
        var processResult: Alert?
        var tickResult: [Alert] = []

        var acceptsCallCount = 0
        var processCallCount = 0
        var tickCallCount = 0

        init(id: String = "mock", isEnabled: Bool = true) {
            self.id = id
            self.isEnabled = isEnabled
        }

        func accepts(_ entry: LogEntry) -> Bool {
            acceptsCallCount += 1
            return acceptsResult
        }

        func process(_ entry: LogEntry) -> Alert? {
            processCallCount += 1
            return processResult
        }

        func tick() -> [Alert] {
            tickCallCount += 1
            return tickResult
        }
    }

    private func makeEntry(message: String = "test") -> LogEntry {
        LogEntry(
            timestamp: Date(),
            process: "kernel",
            processID: 0,
            subsystem: "",
            category: "",
            messageType: "Default",
            eventMessage: message
        )
    }

    @Test func protocolRequiresID() {
        let detector = MockDetector(id: "P01")
        #expect(detector.id == "P01")
    }

    @Test func protocolRequiresIsEnabled() {
        let detector = MockDetector(isEnabled: false)
        #expect(!detector.isEnabled)
        detector.isEnabled = true
        #expect(detector.isEnabled)
    }

    @Test func acceptsReturnsConfiguredValue() {
        let detector = MockDetector()
        detector.acceptsResult = true

        let entry = makeEntry()
        #expect(detector.accepts(entry))
        #expect(detector.acceptsCallCount == 1)
    }

    @Test func processReturnsNilByDefault() {
        let detector = MockDetector()
        let entry = makeEntry()

        #expect(detector.process(entry) == nil)
        #expect(detector.processCallCount == 1)
    }

    @Test func processReturnsConfiguredAlert() {
        let detector = MockDetector()
        let alert = Alert(
            detectorID: "mock",
            severity: .warning,
            title: "Test",
            description: "desc",
            suggestion: "sug",
            timestamp: Date()
        )
        detector.processResult = alert

        let entry = makeEntry()
        let result = detector.process(entry)

        #expect(result != nil)
        #expect(result?.detectorID == "mock")
    }

    @Test func tickReturnsEmptyByDefault() {
        let detector = MockDetector()
        let alerts = detector.tick()

        #expect(alerts.isEmpty)
        #expect(detector.tickCallCount == 1)
    }

    @Test func tickReturnsConfiguredAlerts() {
        let detector = MockDetector()
        let alert = Alert(
            detectorID: "mock",
            severity: .critical,
            title: "Leak",
            description: "desc",
            suggestion: "sug",
            timestamp: Date()
        )
        detector.tickResult = [alert]

        let alerts = detector.tick()
        #expect(alerts.count == 1)
        #expect(alerts[0].severity == .critical)
    }

    @Test func multipleDetectorsCanExistInArray() {
        let detectors: [any PatternDetector] = [
            MockDetector(id: "P01"),
            MockDetector(id: "P02"),
            MockDetector(id: "P03")
        ]
        #expect(detectors.count == 3)
        #expect(detectors[0].id == "P01")
        #expect(detectors[2].id == "P03")
    }
}
