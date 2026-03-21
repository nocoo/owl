import Testing
import Foundation
@testable import OwlCore

@Suite("ProcessStatsProvider")
struct ProcessStatsProviderTests {

    // MARK: - parseCPUTime

    @Test func parseCPUTimeMinutesAndSeconds() {
        #expect(ProcessStatsProvider.parseCPUTime("41:22.45") == 2482)
    }

    @Test func parseCPUTimeZero() {
        #expect(ProcessStatsProvider.parseCPUTime("0:00.00") == 0)
    }

    @Test func parseCPUTimeSingleDigitMinutes() {
        #expect(ProcessStatsProvider.parseCPUTime("1:30.00") == 90)
    }

    @Test func parseCPUTimeLargeHours() {
        // 100 minutes = 6000 seconds + 5
        #expect(ProcessStatsProvider.parseCPUTime("100:05.99") == 6005)
    }

    @Test func parseCPUTimeInvalidReturnsZero() {
        #expect(ProcessStatsProvider.parseCPUTime("invalid") == 0)
    }

    // MARK: - extractProcessName

    @Test func extractProcessNameFromFullPath() {
        #expect(
            ProcessStatsProvider.extractProcessName(
                from: "/usr/sbin/mDNSResponder"
            ) == "mDNSResponder"
        )
    }

    @Test func extractProcessNameFromBareName() {
        #expect(
            ProcessStatsProvider.extractProcessName(
                from: "WindowServer"
            ) == "WindowServer"
        )
    }

    @Test func extractProcessNameFromPathWithSpaces() {
        #expect(
            ProcessStatsProvider.extractProcessName(
                from: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
            ) == "Google Chrome"
        )
    }

    @Test func extractProcessNameEmptyReturnsEmpty() {
        #expect(
            ProcessStatsProvider.extractProcessName(from: "") == ""
        )
    }

    // MARK: - parse

    @Test func parseAggregatesBySameName() {
        let output = """
        CPUTIME    RSS COMM
          1:00.00  1024 /usr/bin/foo
          2:00.00  2048 /usr/bin/foo
        """
        let rankings = ProcessStatsProvider.parse(
            output: output, top: 25
        )
        #expect(rankings.count == 1)
        #expect(rankings[0].id == "foo")
        #expect(rankings[0].cpuSeconds == 180) // 60 + 120
        #expect(rankings[0].memoryMB == 3)     // (1024+2048)/1024
        #expect(rankings[0].instanceCount == 2)
    }

    @Test func parseSortsByCPUDescending() {
        let output = """
        CPUTIME    RSS COMM
          0:10.00  100 small
          5:00.00  200 big
          1:00.00  150 medium
        """
        let rankings = ProcessStatsProvider.parse(
            output: output, top: 25
        )
        #expect(rankings.count == 3)
        #expect(rankings[0].id == "big")
        #expect(rankings[1].id == "medium")
        #expect(rankings[2].id == "small")
    }

    @Test func parseRespectsTopLimit() {
        let output = """
        CPUTIME    RSS COMM
          3:00.00  100 a
          2:00.00  100 b
          1:00.00  100 c
        """
        let rankings = ProcessStatsProvider.parse(
            output: output, top: 2
        )
        #expect(rankings.count == 2)
        #expect(rankings[0].id == "a")
        #expect(rankings[1].id == "b")
    }

    @Test func parseSkipsHeaderAndEmptyLines() {
        let output = """
        CPUTIME    RSS COMM

          1:00.00  512 test

        """
        let rankings = ProcessStatsProvider.parse(
            output: output, top: 25
        )
        #expect(rankings.count == 1)
        #expect(rankings[0].id == "test")
    }

    @Test func parseEmptyOutputReturnsEmpty() {
        let rankings = ProcessStatsProvider.parse(
            output: "", top: 25
        )
        #expect(rankings.isEmpty)
    }

    @Test func parseSkipsRealTIMEHeader() {
        // Real ps output uses "TIME" not "CPUTIME"
        let output = """
             TIME    RSS COMM
          2:16.14  30544 /sbin/launchd
        """
        let rankings = ProcessStatsProvider.parse(
            output: output, top: 25
        )
        #expect(rankings.count == 1)
        #expect(rankings[0].id == "launchd")
    }

    @Test func parseExtractsNameFromPath() {
        let output = """
        CPUTIME    RSS COMM
          1:00.00  1024 /System/Library/Frameworks/Something.framework/Versions/A/Something
        """
        let rankings = ProcessStatsProvider.parse(
            output: output, top: 25
        )
        #expect(rankings.count == 1)
        #expect(rankings[0].id == "Something")
    }

    // MARK: - ProcessRanking formatting

    @Test func cpuTimeFormattedHoursAndMinutes() {
        let r = ProcessRanking(
            id: "test",
            cpuSeconds: 3661,
            memoryMB: 100,
            instanceCount: 1
        )
        #expect(r.cpuTimeFormatted == "1h 1m")
    }

    @Test func cpuTimeFormattedMinutesAndSeconds() {
        let r = ProcessRanking(
            id: "test",
            cpuSeconds: 125,
            memoryMB: 100,
            instanceCount: 1
        )
        #expect(r.cpuTimeFormatted == "2m 5s")
    }

    @Test func cpuTimeFormattedSecondsOnly() {
        let r = ProcessRanking(
            id: "test",
            cpuSeconds: 45,
            memoryMB: 100,
            instanceCount: 1
        )
        #expect(r.cpuTimeFormatted == "45s")
    }

    @Test func memoryFormattedMB() {
        let r = ProcessRanking(
            id: "test",
            cpuSeconds: 0,
            memoryMB: 512,
            instanceCount: 1
        )
        #expect(r.memoryFormatted == "512 MB")
    }

    @Test func memoryFormattedGB() {
        let r = ProcessRanking(
            id: "test",
            cpuSeconds: 0,
            memoryMB: 2048,
            instanceCount: 1
        )
        #expect(r.memoryFormatted == "2.0 GB")
    }

    @Test func memoryFormattedGBFractional() {
        let r = ProcessRanking(
            id: "test",
            cpuSeconds: 0,
            memoryMB: 1536,
            instanceCount: 1
        )
        #expect(r.memoryFormatted == "1.5 GB")
    }

    // MARK: - ProcessStats uptime

    @Test func processStatsUptime() {
        let boot = Date(timeIntervalSince1970: 1000)
        let snap = Date(timeIntervalSince1970: 5000)
        let stats = ProcessStats(
            bootTime: boot, snapshotTime: snap, rankings: []
        )
        #expect(stats.uptime == 4000)
    }

    // MARK: - bootTime (live test)

    @Test func bootTimeReturnsReasonableDate() {
        let provider = ProcessStatsProvider()
        let boot = provider.bootTime()
        // Boot time should be in the past but not too far
        #expect(boot < Date())
        // Should be within the last year
        let oneYearAgo = Date().addingTimeInterval(-365 * 86400)
        #expect(boot > oneYearAgo)
    }

    // MARK: - ProcessRanking identity

    @Test func processRankingIsIdentifiable() {
        let r = ProcessRanking(
            id: "foo",
            cpuSeconds: 10,
            memoryMB: 50,
            instanceCount: 1
        )
        #expect(r.id == "foo")
    }

    @Test func processRankingEquatable() {
        let a = ProcessRanking(
            id: "foo",
            cpuSeconds: 10,
            memoryMB: 50,
            instanceCount: 1
        )
        let b = ProcessRanking(
            id: "foo",
            cpuSeconds: 10,
            memoryMB: 50,
            instanceCount: 1
        )
        #expect(a == b)
    }
}
