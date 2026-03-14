import Testing
@testable import OwlCore

@Suite("PreFilter — UTF-8 byte-level keyword matching")
struct PreFilterTests {

    // MARK: - Each keyword matches independently

    @Test(arguments: [
        "PMRD", "power budget", "QUIT", "tx_flush",
        "LQM", "RSSI", "deny", "PreventSleep",
        "exited due to signal", "disconnect",
        "AUTHREQ_RESULT", "DENIED", "memorystatus_kill",
        "failed to act on a ping", "connection_failed",
        "Connection reset", "nw_endpoint_flow_failed",
        "reporting state failed error",
        "abortGated", "abort", "DarkWake"
    ])
    func keywordAloneMatches(_ keyword: String) {
        #expect(LogStreamReader.passesPreFilter(keyword) == true)
    }

    // MARK: - Keywords embedded in NDJSON lines

    @Test func keywordEmbeddedInJSON() {
        let line = """
        {"traceID":"0","eventMessage":"PMRD: powerd is active","timestamp":"2025-01-01"}
        """
        #expect(LogStreamReader.passesPreFilter(line) == true)
    }

    @Test func abortInEventMessage() {
        let line = """
        {"eventMessage":"Process abort detected","processName":"kernel"}
        """
        #expect(LogStreamReader.passesPreFilter(line) == true)
    }

    @Test func darkWakeInFullLogLine() {
        let line = """
        {"eventMessage":"DarkWake from Deep Idle [CDNP]","subsystem":"com.apple.powermanagement"}
        """
        #expect(LogStreamReader.passesPreFilter(line) == true)
    }

    @Test func connectionResetEmbedded() {
        let line = """
        {"eventMessage":"Connection reset by peer","processName":"nsurlsessiond"}
        """
        #expect(LogStreamReader.passesPreFilter(line) == true)
    }

    // MARK: - No keyword → false

    @Test func lineWithNoKeywordReturnsFalse() {
        let line = """
        {"eventMessage":"Normal operation ongoing","processName":"launchd"}
        """
        #expect(LogStreamReader.passesPreFilter(line) == false)
    }

    @Test func randomTextReturnsFalse() {
        #expect(
            LogStreamReader.passesPreFilter(
                "Hello world, nothing to see here"
            ) == false
        )
    }

    // MARK: - Empty string → false

    @Test func emptyStringReturnsFalse() {
        #expect(LogStreamReader.passesPreFilter("") == false)
    }

    // MARK: - Case sensitivity

    @Test func lowercaseDarkwakeDoesNotMatch() {
        // "DarkWake" is a keyword; "darkwake" should NOT match
        #expect(
            LogStreamReader.passesPreFilter("darkwake event") == false
        )
    }

    @Test func lowercasePmrdDoesNotMatch() {
        #expect(
            LogStreamReader.passesPreFilter("pmrd active") == false
        )
    }

    @Test func lowercaseDeniedDoesNotMatch() {
        // "DENIED" is a keyword; "denied" should NOT match
        #expect(
            LogStreamReader.passesPreFilter("access denied") == false
        )
    }

    @Test func lowercaseQuitDoesNotMatch() {
        // "QUIT" is a keyword; "quit" should NOT match
        #expect(
            LogStreamReader.passesPreFilter("user quit app") == false
        )
    }

    // Note: "deny" is a keyword (lowercase), so lowercase matches
    @Test func lowercaseDenyDoesMatch() {
        #expect(
            LogStreamReader.passesPreFilter("deny access") == true
        )
    }

    // MARK: - Substring matching

    @Test func abortMatchesInsideAbortGated() {
        // "abort" is a keyword substring within "abortGated"
        #expect(
            LogStreamReader.passesPreFilter("abortGated call") == true
        )
    }

    @Test func abortMatchesStandalone() {
        #expect(
            LogStreamReader.passesPreFilter("abort") == true
        )
    }

    @Test func denyMatchesInsideDenied() {
        // "deny" appears as substring of "DENIED"
        // but "DENIED" itself is also a keyword.
        // Test that "deny_request" matches via "deny" keyword.
        #expect(
            LogStreamReader.passesPreFilter("deny_request") == true
        )
    }

    // MARK: - Keyword position: beginning, middle, end

    @Test func keywordAtBeginning() {
        #expect(
            LogStreamReader.passesPreFilter(
                "DarkWake from Deep Idle"
            ) == true
        )
    }

    @Test func keywordInMiddle() {
        #expect(
            LogStreamReader.passesPreFilter(
                "system DarkWake event detected"
            ) == true
        )
    }

    @Test func keywordAtEnd() {
        #expect(
            LogStreamReader.passesPreFilter(
                "entering DarkWake"
            ) == true
        )
    }

    @Test func keywordExactMatch() {
        // Line is exactly the keyword, no surrounding text
        #expect(
            LogStreamReader.passesPreFilter("memorystatus_kill") == true
        )
    }

    // MARK: - Multiple keywords in one line

    @Test func multipleKeywordsStillMatch() {
        let line = "PMRD power budget abort DarkWake"
        #expect(LogStreamReader.passesPreFilter(line) == true)
    }
}
