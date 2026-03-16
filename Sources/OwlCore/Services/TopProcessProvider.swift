import Darwin
import Foundation

/// Raw per-PID CPU time + memory snapshot (lightweight, no name resolution).
public struct ProcessSnapshot: Sendable {
    public let pid: pid_t
    public let cpuTimeNs: UInt64
    /// Resident set size in bytes (from pti_resident_size).
    /// phys_footprint would be more accurate but requires root
    /// privileges for other processes (proc_pid_rusage returns EPERM).
    public let memoryBytes: UInt64

    public init(
        pid: pid_t,
        cpuTimeNs: UInt64,
        memoryBytes: UInt64 = 0
    ) {
        self.pid = pid
        self.cpuTimeNs = cpuTimeNs
        self.memoryBytes = memoryBytes
    }
}

/// Intermediate result: PID + computed CPU percent (before name resolution).
public struct PidCPUPercent: Sendable {
    public let pid: pid_t
    public let percent: Double

    public init(pid: pid_t, percent: Double) {
        self.pid = pid
        self.percent = percent
    }
}

/// Reads top processes by CPU usage via libproc.
public struct TopProcessProvider: Sendable {
    /// Mach absolute-time → nanosecond multiplier (computed once).
    private static let machToNano: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom)
    }()

    public init() {}

    /// Snapshot ALL running processes with their cumulative CPU time.
    /// Lightweight: no proc_name calls. Use this for delta calculation.
    public func allProcessSnapshots() -> [ProcessSnapshot] {
        let bufSize = proc_listallpids(nil, 0)
        guard bufSize > 0 else { return [] }

        var pids = [pid_t](
            repeating: 0, count: Int(bufSize)
        )
        let actualSize = proc_listallpids(
            &pids, bufSize * Int32(MemoryLayout<pid_t>.size)
        )
        guard actualSize > 0 else { return [] }

        let pidCount = Int(actualSize)

        var snapshots: [ProcessSnapshot] = []
        snapshots.reserveCapacity(min(pidCount, 500))

        for idx in 0..<pidCount {
            let pid = pids[idx]
            guard pid > 0 else { continue }

            var taskInfo = proc_taskinfo()
            let infoSize = MemoryLayout<proc_taskinfo>.size
            let result = proc_pidinfo(
                pid,
                PROC_PIDTASKINFO,
                0,
                &taskInfo,
                Int32(infoSize)
            )
            guard result == infoSize else { continue }

            // pti_total_user/system already include live-thread
            // times, so we must NOT add pti_threads_* on top.
            // Values are in Mach absolute-time ticks; convert to
            // nanoseconds so computeDelta's math is correct.
            let machTicks = taskInfo.pti_total_user
                + taskInfo.pti_total_system
            let cpuTimeNs = UInt64(
                Double(machTicks) * Self.machToNano
            )

            snapshots.append(ProcessSnapshot(
                pid: pid,
                cpuTimeNs: cpuTimeNs,
                memoryBytes: UInt64(taskInfo.pti_resident_size)
            ))
        }

        return snapshots
    }

    /// Resolve process name for a given PID.
    public static func resolveProcessName(
        pid: pid_t
    ) -> String? {
        var nameBuffer = [CChar](repeating: 0, count: 256)
        proc_name(pid, &nameBuffer, 256)
        let name = String(cString: nameBuffer)
        return name.isEmpty ? nil : name
    }

    /// Pure delta calculation: computes CPU percent for all
    /// processes present in both snapshots. No name resolution.
    /// Returns sorted by percent descending, limited to `count`.
    public static func computeDelta(
        previous: [ProcessSnapshot],
        current: [ProcessSnapshot],
        interval: TimeInterval,
        coreCount: Int,
        count: Int = 5
    ) -> [PidCPUPercent] {
        let prevMap = Dictionary(
            uniqueKeysWithValues: previous.map {
                ($0.pid, $0.cpuTimeNs)
            }
        )

        let nsPerInterval = interval * 1_000_000_000
        let maxPercent = Double(coreCount) * 100.0

        var results: [PidCPUPercent] = []
        for snap in current {
            guard let prevTime = prevMap[snap.pid] else {
                continue
            }
            let delta = snap.cpuTimeNs >= prevTime
                ? snap.cpuTimeNs - prevTime : 0
            guard delta > 0 else { continue }
            let percent = min(
                (Double(delta) / nsPerInterval) * 100.0,
                maxPercent
            )
            guard percent >= 0.1 else { continue }
            results.append(PidCPUPercent(
                pid: snap.pid, percent: percent
            ))
        }

        results.sort { $0.percent > $1.percent }
        return Array(results.prefix(count))
    }

    /// Computes CPU percent from two full snapshots, then
    /// resolves names for only the top results.
    /// Over-fetches from computeDelta so that name-resolution
    /// failures don't reduce the final count below `count`.
    public static func computeCPUPercent(
        previous: [ProcessSnapshot],
        current: [ProcessSnapshot],
        interval: TimeInterval,
        coreCount: Int,
        count: Int = 5
    ) -> [ProcessMetric] {
        // Fetch extra candidates so exited-process losses
        // don't reduce the result below the requested count.
        let topDeltas = computeDelta(
            previous: previous,
            current: current,
            interval: interval,
            coreCount: coreCount,
            count: count + 5
        )

        var results: [ProcessMetric] = []
        results.reserveCapacity(count)
        for entry in topDeltas {
            guard results.count < count else { break }
            guard let name = resolveProcessName(
                pid: entry.pid
            ) else {
                continue
            }
            results.append(ProcessMetric(
                id: entry.pid,
                name: name,
                cpuPercent: entry.percent
            ))
        }
        return results
    }

    /// Returns the top N processes by resident memory from a
    /// single snapshot. No delta needed — memory is an instant
    /// metric, not cumulative.
    public static func computeTopMemory(
        snapshots: [ProcessSnapshot],
        count: Int = 5
    ) -> [ProcessMemoryMetric] {
        // Filter out kernel (pid 0) and tiny processes
        let sorted = snapshots
            .filter { $0.pid > 0 && $0.memoryBytes > 0 }
            .sorted { $0.memoryBytes > $1.memoryBytes }

        // Walk sorted list, resolve names, collect up to
        // `count` entries. Skips exited processes without
        // reducing the result count.
        var results: [ProcessMemoryMetric] = []
        results.reserveCapacity(count)
        for snap in sorted {
            guard results.count < count else { break }
            guard let name = resolveProcessName(
                pid: snap.pid
            ) else {
                continue
            }
            results.append(ProcessMemoryMetric(
                id: snap.pid,
                name: name,
                memoryBytes: snap.memoryBytes
            ))
        }
        return results
    }
}
