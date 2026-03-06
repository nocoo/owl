import Darwin

/// Reads per-core CPU ticks via host_processor_info.
public struct PerCoreCPUProvider: Sendable {
    public init() {}

    /// Returns tick counts for each logical core.
    public func coreTicks() -> [CoreCPUTicks] {
        var processorCount: natural_t = 0
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &infoArray,
            &infoCount
        )

        guard result == KERN_SUCCESS,
            let info = infoArray
        else { return [] }

        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(
                    bitPattern: info
                ),
                vm_size_t(
                    Int(infoCount)
                    * MemoryLayout<integer_t>.stride
                )
            )
        }

        var cores: [CoreCPUTicks] = []
        cores.reserveCapacity(Int(processorCount))

        let stride = Int(CPU_STATE_MAX)
        for core in 0..<Int(processorCount) {
            let base = core * stride
            cores.append(CoreCPUTicks(
                coreID: core,
                user: UInt64(info[base + Int(CPU_STATE_USER)]),
                system: UInt64(
                    info[base + Int(CPU_STATE_SYSTEM)]
                ),
                idle: UInt64(info[base + Int(CPU_STATE_IDLE)]),
                nice: UInt64(info[base + Int(CPU_STATE_NICE)])
            ))
        }

        return cores
    }

    /// Returns load averages (1, 5, 15 min).
    public func loadAverage() -> LoadAverage {
        var averages = [Double](repeating: 0, count: 3)
        let count = getloadavg(&averages, 3)
        guard count == 3 else { return .zero }
        return LoadAverage(
            one: averages[0],
            five: averages[1],
            fifteen: averages[2]
        )
    }
}
