import Darwin
import Foundation

/// Reads top processes by CPU usage via libproc.
public struct TopProcessProvider: Sendable {
    public init() {}

    /// Returns the top N processes by CPU usage.
    public func topProcesses(count: Int = 5) -> [ProcessMetric] {
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

        // Phase 1: Collect CPU times only (skip expensive proc_name).
        // Use a lightweight struct to hold (pid, cpuTimeNs).
        struct PidCPU {
            let pid: pid_t
            let cpuTimeNs: UInt64
        }

        var candidates: [PidCPU] = []
        candidates.reserveCapacity(min(pidCount, 200))

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

            let cpuTimeNs = taskInfo.pti_total_user
                + taskInfo.pti_total_system

            candidates.append(PidCPU(
                pid: pid, cpuTimeNs: cpuTimeNs
            ))
        }

        // Phase 2: Sort by CPU time descending, take top N.
        candidates.sort { $0.cpuTimeNs > $1.cpuTimeNs }
        let topCandidates = candidates.prefix(count)

        // Phase 3: Resolve process names only for top N.
        var entries: [ProcessMetric] = []
        entries.reserveCapacity(topCandidates.count)

        for candidate in topCandidates {
            var nameBuffer = [CChar](repeating: 0, count: 256)
            proc_name(candidate.pid, &nameBuffer, 256)
            let name = String(cString: nameBuffer)
            guard !name.isEmpty else { continue }

            entries.append(ProcessMetric(
                id: candidate.pid,
                name: name,
                cpuPercent: Double(candidate.cpuTimeNs)
            ))
        }

        return entries
    }

    /// Computes CPU percent from two snapshots taken
    /// `interval` seconds apart.
    public static func computeCPUPercent(
        previous: [ProcessMetric],
        current: [ProcessMetric],
        interval: TimeInterval,
        coreCount: Int
    ) -> [ProcessMetric] {
        let prevMap = Dictionary(
            uniqueKeysWithValues: previous.map {
                ($0.id, $0.cpuPercent)
            }
        )

        let nsPerInterval = interval * 1_000_000_000
        let maxPercent = Double(coreCount) * 100.0

        return current.compactMap { proc in
            guard let prevTime = prevMap[proc.id] else {
                return nil
            }
            let delta = proc.cpuPercent - prevTime
            guard delta > 0 else { return nil }
            let percent = min(
                (delta / nsPerInterval) * 100.0,
                maxPercent
            )
            guard percent >= 0.1 else { return nil }
            return ProcessMetric(
                id: proc.id,
                name: proc.name,
                cpuPercent: percent
            )
        }
        .sorted { $0.cpuPercent > $1.cpuPercent }
    }
}
