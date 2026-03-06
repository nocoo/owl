import Foundation
import Testing
@testable import OwlCore

@Suite("Alert")
struct AlertTests {

    // MARK: - Initialization

    @Test func initializesWithAllFields() {
        let now = Date()
        let alert = Alert(
            detectorID: "P01",
            severity: .warning,
            title: "Thermal Throttling",
            description: "CPU power budget dropped to 4500mW",
            suggestion: "Close resource-intensive apps",
            timestamp: now,
            ttl: 300
        )

        #expect(alert.detectorID == "P01")
        #expect(alert.severity == .warning)
        #expect(alert.title == "Thermal Throttling")
        #expect(alert.description == "CPU power budget dropped to 4500mW")
        #expect(alert.suggestion == "Close resource-intensive apps")
        #expect(alert.timestamp == now)
        #expect(alert.ttl == 300)
    }

    // MARK: - Default TTL by severity

    @Test func defaultTTLForInfo() {
        let alert = Alert(
            detectorID: "P01",
            severity: .info,
            title: "Info",
            description: "desc",
            suggestion: "sug",
            timestamp: Date()
        )
        #expect(alert.ttl == 60)
    }

    @Test func defaultTTLForWarning() {
        let alert = Alert(
            detectorID: "P01",
            severity: .warning,
            title: "Warning",
            description: "desc",
            suggestion: "sug",
            timestamp: Date()
        )
        #expect(alert.ttl == 300)
    }

    @Test func defaultTTLForCritical() {
        let alert = Alert(
            detectorID: "P01",
            severity: .critical,
            title: "Critical",
            description: "desc",
            suggestion: "sug",
            timestamp: Date()
        )
        #expect(alert.ttl == 600)
    }

    @Test func defaultTTLForNormal() {
        let alert = Alert(
            detectorID: "P01",
            severity: .normal,
            title: "Normal",
            description: "desc",
            suggestion: "sug",
            timestamp: Date()
        )
        #expect(alert.ttl == 60)
    }

    @Test func customTTLOverridesDefault() {
        let alert = Alert(
            detectorID: "P01",
            severity: .critical,
            title: "Critical",
            description: "desc",
            suggestion: "sug",
            timestamp: Date(),
            ttl: 120
        )
        // Custom TTL should override the default 600 for critical
        #expect(alert.ttl == 120)
    }

    // MARK: - Expiry check

    @Test func isExpiredReturnsFalseWhenFresh() {
        let alert = Alert(
            detectorID: "P01",
            severity: .warning,
            title: "Test",
            description: "desc",
            suggestion: "sug",
            timestamp: Date(),
            ttl: 300
        )
        #expect(!alert.isExpired(at: Date()))
    }

    @Test func isExpiredReturnsTrueAfterTTL() {
        let past = Date(timeIntervalSinceNow: -400)
        let alert = Alert(
            detectorID: "P01",
            severity: .warning,
            title: "Test",
            description: "desc",
            suggestion: "sug",
            timestamp: past,
            ttl: 300
        )
        #expect(alert.isExpired(at: Date()))
    }

    @Test func isExpiredReturnsFalseAtExactBoundary() {
        let now = Date()
        let alert = Alert(
            detectorID: "P01",
            severity: .warning,
            title: "Test",
            description: "desc",
            suggestion: "sug",
            timestamp: now,
            ttl: 300
        )
        // Exactly at TTL boundary — should not be expired yet
        let boundary = now.addingTimeInterval(300)
        #expect(!alert.isExpired(at: boundary))
    }

    @Test func isExpiredReturnsTrueJustPastBoundary() {
        let now = Date()
        let alert = Alert(
            detectorID: "P01",
            severity: .warning,
            title: "Test",
            description: "desc",
            suggestion: "sug",
            timestamp: now,
            ttl: 300
        )
        let pastBoundary = now.addingTimeInterval(300.001)
        #expect(alert.isExpired(at: pastBoundary))
    }

    // MARK: - Sendable conformance

    @Test func isSendable() async {
        let alert = Alert(
            detectorID: "P01",
            severity: .critical,
            title: "Test",
            description: "desc",
            suggestion: "sug",
            timestamp: Date(),
            ttl: 600
        )

        let task = Task { alert.detectorID }
        let result = await task.value
        #expect(result == "P01")
    }

    // MARK: - Equatable

    @Test func equalAlertsAreEqual() {
        let now = Date()
        let alert1 = Alert(
            detectorID: "P01",
            severity: .warning,
            title: "Test",
            description: "desc",
            suggestion: "sug",
            timestamp: now,
            ttl: 300
        )
        let alert2 = Alert(
            detectorID: "P01",
            severity: .warning,
            title: "Test",
            description: "desc",
            suggestion: "sug",
            timestamp: now,
            ttl: 300
        )
        #expect(alert1 == alert2)
    }

    @Test func differentDetectorIDMakesNotEqual() {
        let now = Date()
        let alert1 = Alert(
            detectorID: "P01",
            severity: .warning,
            title: "Test",
            description: "desc",
            suggestion: "sug",
            timestamp: now,
            ttl: 300
        )
        let alert2 = Alert(
            detectorID: "P02",
            severity: .warning,
            title: "Test",
            description: "desc",
            suggestion: "sug",
            timestamp: now,
            ttl: 300
        )
        #expect(alert1 != alert2)
    }

    // MARK: - Clipboard text

    @Test func clipboardTextContainsSeverityAndTitle() {
        let alert = Alert(
            detectorID: "thermal_throttling",
            severity: .warning,
            title: "Thermal Throttling",
            description: "CPU power budget dropped",
            suggestion: "Close apps",
            timestamp: Date()
        )
        let text = alert.clipboardText
        #expect(text.contains("[warning] Thermal Throttling"))
        #expect(text.contains("CPU power budget dropped"))
        #expect(text.contains("Suggestion: Close apps"))
        #expect(text.contains("Detector: thermal_throttling"))
    }

    @Test func clipboardTextOmitsSuggestionWhenEmpty() {
        let alert = Alert(
            detectorID: "P01",
            severity: .info,
            title: "Info",
            description: "desc",
            suggestion: "",
            timestamp: Date()
        )
        let text = alert.clipboardText
        #expect(!text.contains("Suggestion:"))
    }
}
