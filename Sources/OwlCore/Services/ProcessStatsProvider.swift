import Foundation

/// Aggregated process statistics since boot.
public struct ProcessStats: Sendable, Equatable {
    /// System boot time.
    public let bootTime: Date
    /// Snapshot time.
    public let snapshotTime: Date
    /// Top processes ranked by cumulative CPU time.
    public let rankings: [ProcessRanking]

    /// Uptime duration since boot.
    public var uptime: TimeInterval {
        snapshotTime.timeIntervalSince(bootTime)
    }

    public init(
        bootTime: Date,
        snapshotTime: Date,
        rankings: [ProcessRanking]
    ) {
        self.bootTime = bootTime
        self.snapshotTime = snapshotTime
        self.rankings = rankings
    }
}

/// A single row in the process ranking table.
public struct ProcessRanking: Sendable, Equatable, Identifiable {
    public let id: String // process name
    /// Cumulative CPU time in seconds since boot.
    public let cpuSeconds: Int
    /// Resident memory in MB (sum of all instances).
    public let memoryMB: Int
    /// Number of running instances with this name.
    public let instanceCount: Int

    public init(
        id: String,
        cpuSeconds: Int,
        memoryMB: Int,
        instanceCount: Int
    ) {
        self.id = id
        self.cpuSeconds = cpuSeconds
        self.memoryMB = memoryMB
        self.instanceCount = instanceCount
    }

    /// CPU time formatted as "Xh Ym" or "Ym Zs".
    public var cpuTimeFormatted: String {
        let h = cpuSeconds / 3600
        let m = (cpuSeconds % 3600) / 60
        let s = cpuSeconds % 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else if m > 0 {
            return "\(m)m \(s)s"
        } else {
            return "\(s)s"
        }
    }

    /// Memory formatted as "X MB" or "X.Y GB".
    public var memoryFormatted: String {
        if memoryMB >= 1024 {
            let gb = Double(memoryMB) / 1024.0
            return String(format: "%.1f GB", gb)
        }
        return "\(memoryMB) MB"
    }
}

/// Fetches system boot time and aggregated per-process CPU/memory stats.
public struct ProcessStatsProvider: Sendable {
    public init() {}

    /// Fetch system boot time via sysctl kern.boottime.
    public func bootTime() -> Date {
        var mib = [CTL_KERN, KERN_BOOTTIME]
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        let result = sysctl(&mib, 2, &bootTime, &size, nil, 0)
        guard result == 0 else { return Date() }
        return Date(
            timeIntervalSince1970: Double(bootTime.tv_sec)
                + Double(bootTime.tv_usec) / 1_000_000
        )
    }

    /// Fetch and aggregate process stats. Runs `ps` in a subprocess.
    public func fetch(top: Int = 25) -> ProcessStats {
        let boot = bootTime()
        let now = Date()
        let rankings = aggregateProcesses(top: top)
        return ProcessStats(
            bootTime: boot,
            snapshotTime: now,
            rankings: rankings
        )
    }

    /// Parse `ps -axo cputime,rss,comm` output into aggregated rankings.
    func aggregateProcesses(top: Int) -> [ProcessRanking] {
        let output = runPS()
        return Self.parse(output: output, top: top)
    }

    /// Run ps command and return raw output.
    func runPS() -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "cputime,rss,comm"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return ""
        }

        // Read pipe BEFORE waitUntilExit to avoid deadlock when
        // pipe buffer fills up (ps output can be large).
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Parse ps output into aggregated rankings (testable).
    static func parse(
        output: String,
        top: Int
    ) -> [ProcessRanking] {
        var cpuTimes: [String: Int] = [:]
        var memAmounts: [String: Int] = [:]
        var counts: [String: Int] = [:]

        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(
                in: .whitespaces
            )
            // Skip header and empty lines
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("TIME"),
                  !trimmed.hasPrefix("CPUTIME")
            else { continue }

            // Format: "HH:MM.SS  RSS_KB  /path/to/comm args..."
            // or:     "HH:MM.SS  RSS_KB  comm"
            let parts = trimmed.split(
                separator: " ",
                maxSplits: 2,
                omittingEmptySubsequences: true
            )
            guard parts.count >= 3 else { continue }

            let timeStr = String(parts[0])
            guard let rssKB = Int(parts[1]) else { continue }
            let commPath = String(parts[2])

            // Parse cputime "HH:MM.SS" or "M:SS.xx"
            let seconds = parseCPUTime(timeStr)

            // Extract base process name from path
            let name = extractProcessName(from: commPath)
            guard !name.isEmpty else { continue }

            cpuTimes[name, default: 0] += seconds
            memAmounts[name, default: 0] += rssKB
            counts[name, default: 0] += 1
        }

        // Build rankings sorted by CPU time descending
        var rankings = cpuTimes.map { name, secs in
            ProcessRanking(
                id: name,
                cpuSeconds: secs,
                memoryMB: (memAmounts[name, default: 0]) / 1024,
                instanceCount: counts[name, default: 0]
            )
        }
        rankings.sort { $0.cpuSeconds > $1.cpuSeconds }
        return Array(rankings.prefix(top))
    }

    /// Parse "H:MM.SS" or "HH:MM.SS" CPU time string to total seconds.
    static func parseCPUTime(_ str: String) -> Int {
        // Format: "H:MM.SS" where H can be multi-digit
        // Split on ":" first, then "." for fractional seconds
        let colonParts = str.split(separator: ":")
        guard colonParts.count == 2 else { return 0 }

        let minutes = Int(colonParts[0]) ?? 0
        // Second part may be "SS.xx" or just "SS"
        let secStr = String(colonParts[1])
        let dotParts = secStr.split(separator: ".")
        let secs = Int(dotParts[0]) ?? 0

        return minutes * 60 + secs
    }

    /// Extract the leaf process name from a full path.
    /// "/usr/bin/foo" -> "foo", "foo" -> "foo"
    static func extractProcessName(from comm: String) -> String {
        // comm may contain spaces (e.g. "Google Chrome Helper (Renderer)")
        // The path is the first component before any space, but might also be
        // a bare name. We take the last "/" component of the first word-ish part.
        // Actually ps -axo comm gives the full path; we want the last path component.
        let trimmed = comm.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }

        // If it starts with /, extract the last path component
        if trimmed.hasPrefix("/") {
            // Full path like "/usr/sbin/mDNSResponder"
            let url = URL(fileURLWithPath: trimmed)
            return url.lastPathComponent
        }

        // Bare name or name with arguments — take the first path component
        // e.g. "com.apple.foo" stays as-is
        return trimmed
    }
}
