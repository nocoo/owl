import Testing
import Foundation
@testable import OwlCore

@Suite("TopProcessProvider")
struct TopProcessProviderTests {

    // MARK: - ProcessSnapshot

    @Test func processSnapshotStoresValues() {
        let snap = ProcessSnapshot(pid: 42, cpuTimeNs: 1_000_000)
        #expect(snap.pid == 42)
        #expect(snap.cpuTimeNs == 1_000_000)
    }

    // MARK: - computeDelta (pure logic, no proc_name)

    @Test func computeReturnsEmptyWhenNoPreviousData() {
        let current = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 1_000_000_000),
        ]
        let result = TopProcessProvider.computeDelta(
            previous: [],
            current: current,
            interval: 2.0,
            coreCount: 8
        )
        #expect(result.isEmpty)
    }

    @Test func computeReturnsEmptyWhenNoOverlap() {
        let previous = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 1_000_000_000),
        ]
        let current = [
            ProcessSnapshot(pid: 2, cpuTimeNs: 2_000_000_000),
        ]
        let result = TopProcessProvider.computeDelta(
            previous: previous,
            current: current,
            interval: 2.0,
            coreCount: 8
        )
        #expect(result.isEmpty)
    }

    @Test func computeCalculatesDeltaCorrectly() {
        // 1 second of CPU time in 2 second interval on 8 cores
        // = (1e9 / 2e9) * 100 = 50%
        let previous = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 1_000_000_000),
        ]
        let current = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 2_000_000_000),
        ]
        let result = TopProcessProvider.computeDelta(
            previous: previous,
            current: current,
            interval: 2.0,
            coreCount: 8
        )
        #expect(result.count == 1)
        #expect(result[0].pid == 1)
        #expect(abs(result[0].percent - 50.0) < 0.01)
    }

    @Test func computeClampsToMaxPercent() {
        // 20 seconds of CPU time in 2 second interval on 2 cores
        // Raw = (20e9 / 2e9) * 100 = 1000%, but max = 200%
        let previous = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 0),
        ]
        let current = [
            ProcessSnapshot(
                pid: 1, cpuTimeNs: 20_000_000_000
            ),
        ]
        let result = TopProcessProvider.computeDelta(
            previous: previous,
            current: current,
            interval: 2.0,
            coreCount: 2
        )
        #expect(result.count == 1)
        #expect(result[0].percent == 200.0)
    }

    @Test func computeFiltersOutBelowThreshold() {
        // Very tiny delta: 100_000 ns in 2s interval
        // = (100_000 / 2e9) * 100 = 0.005% < 0.1 threshold
        let previous = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 1_000_000_000),
        ]
        let current = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 1_000_100_000),
        ]
        let result = TopProcessProvider.computeDelta(
            previous: previous,
            current: current,
            interval: 2.0,
            coreCount: 8
        )
        #expect(result.isEmpty)
    }

    @Test func computeFiltersZeroDelta() {
        let previous = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 5_000_000_000),
        ]
        let current = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 5_000_000_000),
        ]
        let result = TopProcessProvider.computeDelta(
            previous: previous,
            current: current,
            interval: 2.0,
            coreCount: 8
        )
        #expect(result.isEmpty)
    }

    @Test func computeSortsByPercentDescending() {
        let previous = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 0),
            ProcessSnapshot(pid: 2, cpuTimeNs: 0),
            ProcessSnapshot(pid: 3, cpuTimeNs: 0),
        ]
        let current = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 100_000_000),   // small
            ProcessSnapshot(pid: 2, cpuTimeNs: 1_000_000_000), // big
            ProcessSnapshot(pid: 3, cpuTimeNs: 500_000_000),   // medium
        ]
        let result = TopProcessProvider.computeDelta(
            previous: previous,
            current: current,
            interval: 2.0,
            coreCount: 8,
            count: 10
        )
        #expect(result.count == 3)
        #expect(result[0].pid == 2)
        #expect(result[1].pid == 3)
        #expect(result[2].pid == 1)
    }

    @Test func computeRespectsCountLimit() {
        let previous = (1...10).map {
            ProcessSnapshot(pid: Int32($0), cpuTimeNs: 0)
        }
        let current = (1...10).map {
            ProcessSnapshot(
                pid: Int32($0),
                cpuTimeNs: UInt64($0) * 1_000_000_000
            )
        }
        let result = TopProcessProvider.computeDelta(
            previous: previous,
            current: current,
            interval: 2.0,
            coreCount: 8,
            count: 3
        )
        #expect(result.count == 3)
        // Should be the top 3 by percent (pid 10, 9, 8)
        #expect(result[0].pid == 10)
        #expect(result[1].pid == 9)
        #expect(result[2].pid == 8)
    }

    @Test func computeHandlesFullSnapshotsCorrectly() {
        // 100 processes, only 3 have significant delta
        var previous: [ProcessSnapshot] = []
        var current: [ProcessSnapshot] = []

        for i in 1...100 {
            let base = UInt64(i) * 10_000_000_000
            previous.append(ProcessSnapshot(
                pid: Int32(i), cpuTimeNs: base
            ))
            // Processes 50, 51, 52 have distinct deltas:
            // 50 -> 500M ns, 51 -> 1000M ns, 52 -> 1500M ns
            let delta: UInt64
            switch i {
            case 50: delta = 500_000_000
            case 51: delta = 1_000_000_000
            case 52: delta = 1_500_000_000
            default: delta = 0
            }
            current.append(ProcessSnapshot(
                pid: Int32(i), cpuTimeNs: base + delta
            ))
        }

        let result = TopProcessProvider.computeDelta(
            previous: previous,
            current: current,
            interval: 2.0,
            coreCount: 8,
            count: 5
        )

        // Exactly 3 processes had non-zero delta
        #expect(result.count == 3)
        // Sorted by percent desc: pid 52 (largest) > 51 > 50
        #expect(result[0].pid == 52)
        #expect(result[1].pid == 51)
        #expect(result[2].pid == 50)
    }

    @Test func computeHandlesWrappedCounter() {
        // If current < previous (counter wrap), delta should be 0
        let previous = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 5_000_000_000),
        ]
        let current = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 1_000_000_000),
        ]
        let result = TopProcessProvider.computeDelta(
            previous: previous,
            current: current,
            interval: 2.0,
            coreCount: 8
        )
        #expect(result.isEmpty)
    }

    // MARK: - allProcessSnapshots (live test)

    @Test func allProcessSnapshotsReturnsNonEmpty() {
        let provider = TopProcessProvider()
        let snapshots = provider.allProcessSnapshots()
        #expect(snapshots.count > 10)
        for snap in snapshots {
            #expect(snap.pid > 0)
        }
    }

    @Test func allProcessSnapshotsReturnsMoreThanFive() {
        // This was the root cause of the bug: previously
        // topProcesses(count:5) only returned 5, causing
        // delta join misses. Now we should get hundreds.
        let provider = TopProcessProvider()
        let snapshots = provider.allProcessSnapshots()
        #expect(snapshots.count > 50)
    }

    // MARK: - Memory bytes in snapshot

    @Test func snapshotIncludesMemoryBytes() {
        let provider = TopProcessProvider()
        let snapshots = provider.allProcessSnapshots()
        // At least some processes should have non-zero RSS
        let withMemory = snapshots.filter { $0.memoryBytes > 0 }
        #expect(withMemory.count > 10)
    }

    // MARK: - computeTopMemory

    @Test func computeTopMemoryReturnsEmptyForEmptyInput() {
        let result = TopProcessProvider.computeTopMemory(
            snapshots: [],
            count: 5
        )
        #expect(result.isEmpty)
    }

    @Test func computeTopMemoryFiltersZeroMemory() {
        let snapshots = [
            ProcessSnapshot(pid: 1, cpuTimeNs: 0, memoryBytes: 0),
            ProcessSnapshot(pid: 2, cpuTimeNs: 0, memoryBytes: 0),
        ]
        let result = TopProcessProvider.computeTopMemory(
            snapshots: snapshots,
            count: 5
        )
        #expect(result.isEmpty)
    }

    @Test func computeTopMemorySortsByMemoryDescending() {
        // Use the current process PID so proc_name resolves
        // successfully, and parent PID as a second resolvable PID.
        let selfPid = ProcessInfo.processInfo.processIdentifier
        let parentPid = getppid()
        let snapshots = [
            ProcessSnapshot(
                pid: selfPid, cpuTimeNs: 0,
                memoryBytes: 100_000_000
            ),
            ProcessSnapshot(
                pid: parentPid, cpuTimeNs: 0,
                memoryBytes: 500_000_000
            ),
        ]
        let result = TopProcessProvider.computeTopMemory(
            snapshots: snapshots,
            count: 5
        )
        #expect(result.count == 2)
        // Largest memory first
        #expect(result[0].memoryBytes == 500_000_000)
        #expect(result[0].id == parentPid)
        #expect(result[1].memoryBytes == 100_000_000)
        #expect(result[1].id == selfPid)
    }

    @Test func computeTopMemorySkipsUnresolvablePids() {
        // PID 99999 almost certainly doesn't exist, so
        // proc_name will fail and it should be skipped.
        let selfPid = ProcessInfo.processInfo.processIdentifier
        let snapshots = [
            ProcessSnapshot(
                pid: 99999, cpuTimeNs: 0,
                memoryBytes: 999_000_000
            ),
            ProcessSnapshot(
                pid: selfPid, cpuTimeNs: 0,
                memoryBytes: 100_000_000
            ),
        ]
        let result = TopProcessProvider.computeTopMemory(
            snapshots: snapshots,
            count: 5
        )
        // The fake PID should be skipped; only self remains
        #expect(result.count == 1)
        #expect(result[0].id == selfPid)
    }

    @Test func computeTopMemoryRespectsCountLimit() {
        let provider = TopProcessProvider()
        let liveSnapshots = provider.allProcessSnapshots()
        let result = TopProcessProvider.computeTopMemory(
            snapshots: liveSnapshots,
            count: 2
        )
        #expect(result.count <= 2)
    }

    @Test func computeTopMemoryReturnsNonZeroBytes() {
        let provider = TopProcessProvider()
        let liveSnapshots = provider.allProcessSnapshots()
        let result = TopProcessProvider.computeTopMemory(
            snapshots: liveSnapshots,
            count: 5
        )
        for proc in result {
            #expect(proc.memoryBytes > 0)
            #expect(!proc.name.isEmpty)
        }
    }
}
