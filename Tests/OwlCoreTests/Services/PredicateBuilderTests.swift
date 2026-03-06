import Testing
@testable import OwlCore

@Suite("PredicateBuilder")
struct PredicateBuilderTests {

    // MARK: - Full predicate (all patterns enabled)

    @Test func buildAllReturnsNonEmptyString() {
        let predicate = PredicateBuilder.buildAll()
        #expect(!predicate.isEmpty)
    }

    @Test func buildAllContainsAllRequiredProcesses() {
        let predicate = PredicateBuilder.buildAll()
        let expected = [
            "kernel",
            "launchservicesd",
            "launchd",
            "powerd",
            "airportd",
            "bluetoothd",
            "tccd",
            "WindowServer"
        ]
        for process in expected {
            #expect(
                predicate.contains("process == '\(process)'"),
                "Missing process predicate for \(process)"
            )
        }
    }

    @Test func buildAllContainsNetworkCompoundPredicate() {
        let predicate = PredicateBuilder.buildAll()
        #expect(predicate.contains(
            "subsystem == 'com.apple.network' AND ("
        ))
        #expect(predicate.contains("messageType == 16"))
        #expect(predicate.contains(
            "eventMessage CONTAINS 'connection_failed'"
        ))
        #expect(predicate.contains(
            "eventMessage CONTAINS 'Connection reset'"
        ))
        #expect(predicate.contains(
            "eventMessage CONTAINS 'nw_endpoint_flow_failed'"
        ))
    }

    @Test func buildAllUsesORSeparator() {
        let predicate = PredicateBuilder.buildAll()
        #expect(predicate.contains(" OR "))
    }

    @Test func buildAllHasNineTopLevelClauses() {
        // 8 processes + 1 compound network predicate = 9 top-level OR clauses
        // The compound predicate is parenthesized so we count by splitting
        // outside parentheses. Simpler: count process== + the one compound.
        let predicate = PredicateBuilder.buildAll()
        let processCount = predicate
            .components(separatedBy: "process == ").count - 1
        #expect(processCount == 8)
        // Compound predicate is wrapped in parens
        #expect(predicate.contains("(subsystem == 'com.apple.network'"))
    }

    // MARK: - Filtered predicate (subset of patterns)

    @Test func buildFilteredWithSinglePattern() {
        // P01 thermal only needs kernel
        let predicate = PredicateBuilder.build(
            enabledPatternIDs: [ThermalPattern.id]
        )
        #expect(predicate.contains("process == 'kernel'"))
        // Should NOT contain unrelated processes
        #expect(!predicate.contains("bluetoothd"))
        #expect(!predicate.contains("tccd"))
    }

    @Test func buildFilteredDeduplicatesProcesses() {
        // P01 thermal, P03 disk, P05 sandbox all use kernel
        let predicate = PredicateBuilder.build(
            enabledPatternIDs: [
                ThermalPattern.id,
                DiskFlushPattern.id,
                SandboxPattern.id
            ]
        )
        let kernelCount = predicate
            .components(separatedBy: "process == 'kernel'").count - 1
        #expect(kernelCount == 1, "kernel should appear exactly once")
    }

    @Test func buildFilteredWithNetworkPattern() {
        let predicate = PredicateBuilder.build(
            enabledPatternIDs: [NetworkPattern.id]
        )
        #expect(predicate.contains("subsystem == 'com.apple.network'"))
        #expect(predicate.contains("connection_failed"))
        #expect(!predicate.contains("process == 'kernel'"))
    }

    @Test func buildFilteredWithEmptySetReturnsEmpty() {
        let predicate = PredicateBuilder.build(enabledPatternIDs: [])
        #expect(predicate.isEmpty)
    }

    @Test func buildFilteredIgnoresUnknownIDs() {
        let predicate = PredicateBuilder.build(
            enabledPatternIDs: ["nonexistent_pattern"]
        )
        #expect(predicate.isEmpty)
    }

    @Test func buildFilteredWithAllPatternsMatchesBuildAll() {
        let allIDs = PredicateBuilder.allPatternIDs
        let filtered = PredicateBuilder.build(enabledPatternIDs: Set(allIDs))
        let full = PredicateBuilder.buildAll()
        // Both should produce the same set of clauses (order may differ)
        let filteredClauses = Set(
            filtered.components(separatedBy: " OR ")
        )
        let fullClauses = Set(full.components(separatedBy: " OR "))
        #expect(filteredClauses == fullClauses)
    }

    // MARK: - Pattern-to-source mapping correctness

    @Test func thermalPatternMapsToKernel() {
        let sources = PredicateBuilder.sources(
            for: ThermalPattern.id
        )
        #expect(sources.contains(.process("kernel")))
    }

    @Test func crashLoopPatternMapsToLaunchservicesd() {
        let sources = PredicateBuilder.sources(
            for: CrashLoopPattern.id
        )
        #expect(sources.contains(.process("launchservicesd")))
    }

    @Test func networkPatternMapsToCompoundSource() {
        let sources = PredicateBuilder.sources(
            for: NetworkPattern.id
        )
        #expect(sources.count == 1)
        guard case .compound(let expr) = sources.first else {
            Issue.record("Expected compound source")
            return
        }
        #expect(expr.contains("subsystem == 'com.apple.network'"))
        #expect(expr.contains("connection_failed"))
    }

    @Test func darkWakePatternMapsToBothKernelAndPowerd() {
        // P14 DarkWake uses both kernel and powerd
        let sources = PredicateBuilder.sources(
            for: DarkWakePattern.id
        )
        #expect(sources.contains(.process("kernel")))
        #expect(sources.contains(.process("powerd")))
    }

    @Test func sleepAssertionPatternMapsToPowerd() {
        let sources = PredicateBuilder.sources(
            for: SleepAssertionPattern.id
        )
        #expect(sources.contains(.process("powerd")))
    }

    @Test func allPatternsHaveSources() {
        for patternID in PredicateBuilder.allPatternIDs {
            let sources = PredicateBuilder.sources(for: patternID)
            #expect(
                !sources.isEmpty,
                "Pattern \(patternID) has no log sources"
            )
        }
    }

    // MARK: - Predicate format validation

    @Test func predicateContainsNoTrailingOR() {
        let predicate = PredicateBuilder.buildAll()
        #expect(!predicate.hasSuffix(" OR "))
        #expect(!predicate.hasSuffix(" OR"))
    }

    @Test func predicateContainsNoLeadingOR() {
        let predicate = PredicateBuilder.buildAll()
        #expect(!predicate.hasPrefix("OR "))
        #expect(!predicate.hasPrefix(" OR"))
    }

    @Test func filteredPredicateContainsNoTrailingOR() {
        let predicate = PredicateBuilder.build(
            enabledPatternIDs: [ThermalPattern.id]
        )
        #expect(!predicate.hasSuffix(" OR "))
    }
}
