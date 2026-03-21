import Foundation
import Testing
@testable import OwlCore

@Suite("SignatureDetector")
struct SignatureDetectorTests {

    private func makeConfig(
        regex: String = #"service=(\S+) op=(\S+) target=(\S+)"#,
        keyGroupIndex: Int = 1,
        signatureGroupIndexes: [Int] = [2, 3],
        windowSeconds: Int = 60,
        warningDistinct: Int = 3,
        criticalDistinct: Int = 5,
        cooldownInterval: TimeInterval = 60,
        maxGroups: Int = 50,
        normalizer: (@Sendable (String) -> String)? = nil
    ) -> SignatureConfig {
        SignatureConfig(
            id: "sig_test",
            regex: regex,
            keyGroupIndex: keyGroupIndex,
            signatureGroupIndexes: signatureGroupIndexes,
            windowSeconds: windowSeconds,
            warningDistinct: warningDistinct,
            criticalDistinct: criticalDistinct,
            cooldownInterval: cooldownInterval,
            maxGroups: maxGroups,
            titleKey: .alertSandboxTitle,
            descriptionTemplateKey: .alertSandboxDesc("{key}", "{window}", "{count}"),
            suggestionKey: .alertSandboxSuggestion,
            acceptsFilter: "service=",
            normalizer: normalizer
        )
    }

    private func makeEntry(
        message: String,
        timestamp: Date = Date()
    ) -> LogEntry {
        LogEntry(
            timestamp: timestamp,
            process: "kernel",
            processID: 1,
            subsystem: "",
            category: "",
            messageType: "Error",
            eventMessage: message
        )
    }

    @Test func acceptsMatchingMessage() {
        let detector = SignatureDetector(config: makeConfig())
        #expect(detector.accepts(makeEntry(message: "service=app op=read target=/tmp/a")))
    }

    @Test func warningAlertAtDistinctThreshold() {
        let detector = SignatureDetector(config: makeConfig(
            warningDistinct: 3, criticalDistinct: 10, cooldownInterval: 0
        ))
        let t0 = Date(timeIntervalSince1970: 1_000)

        let messages = [
            "service=app op=read target=/tmp/a",
            "service=app op=write target=/tmp/a",
            "service=app op=read target=/tmp/b"
        ]

        var lastAlert: Alert?
        for (offset, message) in messages.enumerated() {
            lastAlert = detector.process(makeEntry(
                message: message,
                timestamp: t0.addingTimeInterval(Double(offset))
            ))
        }

        #expect(lastAlert?.severity == .warning)
        #expect(lastAlert?.description.contains("app") == true)
        #expect(lastAlert?.description.contains("3") == true)
    }

    @Test func duplicateSignatureDoesNotInflateDistinctCount() {
        let detector = SignatureDetector(config: makeConfig(
            warningDistinct: 2, criticalDistinct: 10, cooldownInterval: 0
        ))
        let t0 = Date(timeIntervalSince1970: 2_000)

        _ = detector.process(makeEntry(message: "service=app op=read target=/tmp/a", timestamp: t0))
        let duplicate = detector.process(makeEntry(
            message: "service=app op=read target=/tmp/a",
            timestamp: t0.addingTimeInterval(1)
        ))

        #expect(duplicate == nil)

        let distinct = detector.process(makeEntry(
            message: "service=app op=write target=/tmp/a",
            timestamp: t0.addingTimeInterval(2)
        ))

        #expect(distinct?.severity == .warning)
    }

    @Test func explicitGroupIndexesDriveKeyAndSignatureExtraction() {
        let detector = SignatureDetector(config: makeConfig(
            regex: #"op=(\S+) service=(\S+) target=(\S+)"#,
            keyGroupIndex: 2,
            signatureGroupIndexes: [1, 3],
            warningDistinct: 2,
            criticalDistinct: 10,
            cooldownInterval: 0
        ))
        let t0 = Date(timeIntervalSince1970: 3_000)

        _ = detector.process(makeEntry(message: "op=read service=mail target=/tmp/a", timestamp: t0))
        let alert = detector.process(makeEntry(
            message: "op=write service=mail target=/tmp/a",
            timestamp: t0.addingTimeInterval(1)
        ))

        #expect(alert?.severity == .warning)
        #expect(alert?.description.contains("mail") == true)
    }

    @Test func normalizerCollapsesDynamicTargets() {
        let detector = SignatureDetector(config: makeConfig(
            warningDistinct: 2,
            criticalDistinct: 10,
            cooldownInterval: 0
        ) { target in
            target.replacingOccurrences(
                of: #"/private/var/folders/[A-Za-z0-9_-]+/[A-Za-z0-9_-]+/"#,
                with: "/private/var/folders/<ID>/<ID>/",
                options: .regularExpression
            )
        })
        let t0 = Date(timeIntervalSince1970: 4_000)

        _ = detector.process(makeEntry(
            message: "service=app op=read target=/private/var/folders/aa/bb/tmp/file",
            timestamp: t0
        ))
        let collapsed = detector.process(makeEntry(
            message: "service=app op=read target=/private/var/folders/cc/dd/tmp/file",
            timestamp: t0.addingTimeInterval(1)
        ))

        #expect(collapsed == nil)

        let distinct = detector.process(makeEntry(
            message: "service=app op=write target=/private/var/folders/ee/ff/tmp/file",
            timestamp: t0.addingTimeInterval(2)
        ))

        #expect(distinct?.severity == .warning)
    }

    @Test func signaturesSurviveOneRotationButExpireAfterTwo() {
        let detector = SignatureDetector(config: makeConfig(
            windowSeconds: 10,
            warningDistinct: 3,
            criticalDistinct: 10,
            cooldownInterval: 0
        ))
        let t0 = Date(timeIntervalSince1970: 5_000)

        _ = detector.process(makeEntry(message: "service=app op=read target=/tmp/a", timestamp: t0))
        _ = detector.process(makeEntry(
            message: "service=app op=read target=/tmp/b",
            timestamp: t0.addingTimeInterval(4)
        ))

        let afterOneRotation = detector.process(makeEntry(
            message: "service=app op=read target=/tmp/c",
            timestamp: t0.addingTimeInterval(6)
        ))
        #expect(afterOneRotation?.severity == .warning)

        let afterExpiry = detector.process(makeEntry(
            message: "service=app op=read target=/tmp/d",
            timestamp: t0.addingTimeInterval(16)
        ))
        #expect(afterExpiry == nil)
    }

    @Test func tickCleansUpStaleGroups() {
        let detector = SignatureDetector(config: makeConfig(windowSeconds: 10))
        let t0 = Date(timeIntervalSince1970: 6_000)

        _ = detector.process(makeEntry(message: "service=app op=read target=/tmp/a", timestamp: t0))
        detector.advanceTimeForTesting(to: t0.addingTimeInterval(25))

        let alerts = detector.tick()
        #expect(alerts.isEmpty)
        #expect(detector.groupCount == 0)
    }

    @Test func evictsLeastRecentlySeenGroup() {
        let detector = SignatureDetector(config: makeConfig(
            warningDistinct: 10,
            criticalDistinct: 20,
            cooldownInterval: 60,
            maxGroups: 2
        ))
        let t0 = Date(timeIntervalSince1970: 7_000)

        _ = detector.process(makeEntry(message: "service=app1 op=read target=/tmp/a", timestamp: t0))
        _ = detector.process(makeEntry(
            message: "service=app2 op=read target=/tmp/a",
            timestamp: t0.addingTimeInterval(1)
        ))
        _ = detector.process(makeEntry(
            message: "service=app3 op=read target=/tmp/a",
            timestamp: t0.addingTimeInterval(2)
        ))

        #expect(detector.groupCount == 2)
    }
}
