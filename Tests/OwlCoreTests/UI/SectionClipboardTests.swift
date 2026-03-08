import Testing
@testable import OwlCore

/// Tests for clipboard text generation in all metric sections.
@Suite("Section clipboardText")
struct SectionClipboardTests {

    // MARK: - Helpers

    /// Build a SystemMetrics with realistic values for clipboard tests.
    private static func sampleMetrics(
        cpuUsage: Double = 45.2,
        perCoreCPU: [CoreCPUUsage] = [],
        loadAverage: LoadAverage = LoadAverage(
            one: 3.42, five: 2.81, fifteen: 2.65,
            performanceCores: 0, efficiencyCores: 0
        ),
        extendedMemory: ExtendedMemoryInfo = .zero,
        disk: DiskMetrics = .zero,
        battery: BatteryMetrics = .unavailable,
        network: NetworkMetrics = .zero,
        topProcesses: [ProcessMetric] = [],
        temperatures: [TemperatureSensor] = []
    ) -> SystemMetrics {
        SystemMetrics(
            cpuUsage: cpuUsage,
            memoryTotal: 17_179_869_184, // 16 GB
            memoryUsed: 12_884_901_888, // 12 GB
            perCoreCPU: perCoreCPU,
            loadAverage: loadAverage,
            extendedMemory: extendedMemory,
            disk: disk,
            battery: battery,
            network: network,
            topProcesses: topProcesses,
            temperatures: temperatures
        )
    }

    // MARK: - CPU

    @Test func cpuClipboardTextContainsHeader() {
        let m = Self.sampleMetrics()
        let text = CPUSection.clipboardText(m)
        #expect(text.hasPrefix("[CPU]"))
    }

    @Test func cpuClipboardTextShowsTotalPercentage() {
        let m = Self.sampleMetrics(cpuUsage: 72.5)
        let text = CPUSection.clipboardText(m)
        #expect(text.contains("72.5%"))
    }

    @Test func cpuClipboardTextShowsLoadAverage() {
        let m = Self.sampleMetrics()
        let text = CPUSection.clipboardText(m)
        #expect(text.contains("Load:"))
        #expect(text.contains("3.42"))
        #expect(text.contains("2.81"))
        #expect(text.contains("2.65"))
    }

    @Test func cpuClipboardTextShowsPCores() {
        let cores = (0..<6).map {
            CoreCPUUsage(id: $0, usage: Double($0 * 10 + 10))
        }
        let la = LoadAverage(
            one: 1.0, five: 1.0, fifteen: 1.0,
            performanceCores: 6, efficiencyCores: 0
        )
        let m = Self.sampleMetrics(
            perCoreCPU: cores, loadAverage: la
        )
        let text = CPUSection.clipboardText(m)
        #expect(text.contains("P-Cores ×6"))
        #expect(text.contains("P00"))
        #expect(text.contains("P05"))
    }

    @Test func cpuClipboardTextShowsECores() {
        let pCores = (0..<4).map {
            CoreCPUUsage(id: $0, usage: 50)
        }
        let eCores = (4..<8).map {
            CoreCPUUsage(id: $0, usage: 20)
        }
        let la = LoadAverage(
            one: 1.0, five: 1.0, fifteen: 1.0,
            performanceCores: 4, efficiencyCores: 4
        )
        let m = Self.sampleMetrics(
            perCoreCPU: pCores + eCores, loadAverage: la
        )
        let text = CPUSection.clipboardText(m)
        #expect(text.contains("P-Cores ×4"))
        #expect(text.contains("E-Cores ×4"))
        #expect(text.contains("E04"))
    }

    @Test func cpuClipboardTextFallbackCores() {
        let cores = [
            CoreCPUUsage(id: 0, usage: 30),
            CoreCPUUsage(id: 1, usage: 40),
        ]
        let la = LoadAverage(
            one: 1.0, five: 1.0, fifteen: 1.0,
            performanceCores: 0, efficiencyCores: 0
        )
        let m = Self.sampleMetrics(
            perCoreCPU: cores, loadAverage: la
        )
        let text = CPUSection.clipboardText(m)
        #expect(text.contains("Cores:"))
        #expect(text.contains("C00"))
    }

    // MARK: - Memory

    @Test func memoryClipboardTextContainsHeader() {
        let mem = ExtendedMemoryInfo(
            total: 17_179_869_184,
            used: 12_884_901_888,
            cached: 2_147_483_648,
            available: 4_294_967_296,
            swapTotal: 2_147_483_648,
            swapUsed: 536_870_912,
            pageins: 1_500_000,
            pageouts: 345_000
        )
        let m = Self.sampleMetrics(extendedMemory: mem)
        let text = MemorySection.clipboardText(m)
        #expect(text.hasPrefix("[Memory]"))
    }

    @Test func memoryClipboardTextShowsUsedPercent() {
        let mem = ExtendedMemoryInfo(
            total: 17_179_869_184,
            used: 12_884_901_888,
            cached: 0, available: 0,
            swapTotal: 0, swapUsed: 0
        )
        let m = Self.sampleMetrics(extendedMemory: mem)
        let text = MemorySection.clipboardText(m)
        #expect(text.contains("Used:"))
        #expect(text.contains("75.0%"))
    }

    @Test func memoryClipboardTextShowsSwapWhenPresent() {
        let mem = ExtendedMemoryInfo(
            total: 17_179_869_184,
            used: 12_884_901_888,
            cached: 0, available: 0,
            swapTotal: 2_147_483_648,
            swapUsed: 536_870_912
        )
        let m = Self.sampleMetrics(extendedMemory: mem)
        let text = MemorySection.clipboardText(m)
        #expect(text.contains("Swap:"))
    }

    @Test func memoryClipboardTextOmitsSwapWhenZero() {
        let mem = ExtendedMemoryInfo(
            total: 17_179_869_184,
            used: 12_884_901_888,
            cached: 0, available: 0,
            swapTotal: 0, swapUsed: 0
        )
        let m = Self.sampleMetrics(extendedMemory: mem)
        let text = MemorySection.clipboardText(m)
        #expect(!text.contains("Swap:"))
    }

    @Test func memoryClipboardTextShowsPageCounts() {
        let mem = ExtendedMemoryInfo(
            total: 17_179_869_184,
            used: 12_884_901_888,
            cached: 0, available: 0,
            swapTotal: 0, swapUsed: 0,
            pageins: 1_500_000, pageouts: 345_000
        )
        let m = Self.sampleMetrics(extendedMemory: mem)
        let text = MemorySection.clipboardText(m)
        #expect(text.contains("PageIn: 1.5M"))
        #expect(text.contains("PageOut: 345.0K"))
    }

    // MARK: - Disk

    @Test func diskClipboardTextContainsHeader() {
        let disk = DiskMetrics(
            totalBytes: 500_000_000_000,
            usedBytes: 350_000_000_000,
            readBytesPerSec: 52_428_800,
            writeBytesPerSec: 10_485_760
        )
        let m = Self.sampleMetrics(disk: disk)
        let text = DiskSection.clipboardText(m)
        #expect(text.hasPrefix("[Disk]"))
    }

    @Test func diskClipboardTextShowsUsageAndThroughput() {
        let disk = DiskMetrics(
            totalBytes: 500_000_000_000,
            usedBytes: 350_000_000_000,
            readBytesPerSec: 52_428_800,
            writeBytesPerSec: 10_485_760
        )
        let m = Self.sampleMetrics(disk: disk)
        let text = DiskSection.clipboardText(m)
        #expect(text.contains("Usage:"))
        #expect(text.contains("70.0%"))
        #expect(text.contains("Read:"))
        #expect(text.contains("Write:"))
        #expect(text.contains("Available:"))
    }

    // MARK: - Power

    @Test func powerClipboardTextContainsHeader() {
        let batt = BatteryMetrics(
            level: 85, health: 92, cycleCount: 123,
            isCharging: true, isPluggedIn: true,
            temperature: 35, timeRemaining: 120,
            condition: "Normal", wattage: 45.5
        )
        let m = Self.sampleMetrics(battery: batt)
        let text = PowerSection.clipboardText(m)
        #expect(text.hasPrefix("[Power]"))
    }

    @Test func powerClipboardTextShowsLevelAndHealth() {
        let batt = BatteryMetrics(
            level: 85, health: 92, cycleCount: 123,
            isCharging: false, isPluggedIn: false,
            temperature: nil, timeRemaining: nil,
            condition: "Normal"
        )
        let m = Self.sampleMetrics(battery: batt)
        let text = PowerSection.clipboardText(m)
        #expect(text.contains("Level: 85%"))
        #expect(text.contains("Health: 92%"))
    }

    @Test func powerClipboardTextShowsChargingState() {
        let batt = BatteryMetrics(
            level: 50, health: 90, cycleCount: 100,
            isCharging: true, isPluggedIn: true,
            temperature: nil, timeRemaining: nil,
            condition: "Normal"
        )
        let m = Self.sampleMetrics(battery: batt)
        let text = PowerSection.clipboardText(m)
        #expect(text.contains("State: Charging"))
    }

    @Test func powerClipboardTextShowsPluggedState() {
        let batt = BatteryMetrics(
            level: 100, health: 95, cycleCount: 50,
            isCharging: false, isPluggedIn: true,
            temperature: nil, timeRemaining: nil,
            condition: "Normal"
        )
        let m = Self.sampleMetrics(battery: batt)
        let text = PowerSection.clipboardText(m)
        #expect(text.contains("State: Plugged In"))
    }

    @Test func powerClipboardTextShowsBatteryState() {
        let batt = BatteryMetrics(
            level: 60, health: 88, cycleCount: 200,
            isCharging: false, isPluggedIn: false,
            temperature: nil, timeRemaining: nil,
            condition: "Normal"
        )
        let m = Self.sampleMetrics(battery: batt)
        let text = PowerSection.clipboardText(m)
        #expect(text.contains("State: Battery"))
    }

    @Test func powerClipboardTextShowsWattage() {
        let batt = BatteryMetrics(
            level: 50, health: 90, cycleCount: 100,
            isCharging: true, isPluggedIn: true,
            temperature: nil, timeRemaining: nil,
            condition: "Normal", wattage: 45.5
        )
        let m = Self.sampleMetrics(battery: batt)
        let text = PowerSection.clipboardText(m)
        #expect(text.contains("45.5W"))
    }

    @Test func powerClipboardTextOmitsWattageWhenNil() {
        let batt = BatteryMetrics(
            level: 50, health: 90, cycleCount: 100,
            isCharging: false, isPluggedIn: false,
            temperature: nil, timeRemaining: nil,
            condition: "Normal", wattage: nil
        )
        let m = Self.sampleMetrics(battery: batt)
        let text = PowerSection.clipboardText(m)
        #expect(!text.contains("W"))
    }

    // MARK: - Temperature

    @Test func temperatureClipboardTextContainsHeader() {
        let sensors = [
            TemperatureSensor(label: "CPU", celsius: 52),
            TemperatureSensor(label: "GPU", celsius: 45),
        ]
        let text = TemperatureSection.clipboardText(sensors)
        #expect(text.hasPrefix("[Temperature]"))
    }

    @Test func temperatureClipboardTextShowsSensors() {
        let sensors = [
            TemperatureSensor(label: "CPU", celsius: 52),
            TemperatureSensor(label: "GPU", celsius: 45),
        ]
        let text = TemperatureSection.clipboardText(sensors)
        #expect(text.contains("CPU: 52°C"))
        #expect(text.contains("GPU: 45°C"))
    }

    @Test func temperatureClipboardTextEmptySensors() {
        let text = TemperatureSection.clipboardText([])
        #expect(text.contains("No data"))
    }

    // MARK: - Network

    @Test func networkClipboardTextContainsHeader() {
        let net = NetworkMetrics(
            bytesInPerSec: 5_242_880,
            bytesOutPerSec: 1_048_576,
            activeInterface: "en0",
            localIP: "192.168.1.100"
        )
        let m = Self.sampleMetrics(network: net)
        let text = NetworkSection.clipboardText(m)
        #expect(text.hasPrefix("[Network]"))
    }

    @Test func networkClipboardTextShowsSpeeds() {
        let net = NetworkMetrics(
            bytesInPerSec: 5_242_880,
            bytesOutPerSec: 1_048_576,
            activeInterface: "en0",
            localIP: "192.168.1.100"
        )
        let m = Self.sampleMetrics(network: net)
        let text = NetworkSection.clipboardText(m)
        #expect(text.contains("Down:"))
        #expect(text.contains("Up:"))
        #expect(text.contains("5.0 MB/s"))
        #expect(text.contains("1.0 MB/s"))
    }

    @Test func networkClipboardTextShowsInterface() {
        let net = NetworkMetrics(
            bytesInPerSec: 0,
            bytesOutPerSec: 0,
            activeInterface: "en0",
            localIP: "10.0.0.1"
        )
        let m = Self.sampleMetrics(network: net)
        let text = NetworkSection.clipboardText(m)
        #expect(text.contains("Interface: en0"))
        #expect(text.contains("IP: 10.0.0.1"))
    }

    @Test func networkClipboardTextOmitsInterfaceWhenEmpty() {
        let net = NetworkMetrics(
            bytesInPerSec: 0,
            bytesOutPerSec: 0,
            activeInterface: "",
            localIP: ""
        )
        let m = Self.sampleMetrics(network: net)
        let text = NetworkSection.clipboardText(m)
        #expect(!text.contains("Interface:"))
    }

    // MARK: - Processes

    @Test func processesClipboardTextContainsHeader() {
        let procs = [
            ProcessMetric(id: 100, name: "Safari", cpuPercent: 25.3),
        ]
        let m = Self.sampleMetrics(topProcesses: procs)
        let text = ProcessesSection.clipboardText(m)
        #expect(text.hasPrefix("[Top Processes]"))
    }

    @Test func processesClipboardTextShowsProcesses() {
        let procs = [
            ProcessMetric(id: 100, name: "Safari", cpuPercent: 25.3),
            ProcessMetric(id: 200, name: "Xcode", cpuPercent: 18.7),
            ProcessMetric(id: 300, name: "Finder", cpuPercent: 5.1),
        ]
        let m = Self.sampleMetrics(topProcesses: procs)
        let text = ProcessesSection.clipboardText(m)
        #expect(text.contains("1. Safari 25.3% (pid 100)"))
        #expect(text.contains("2. Xcode 18.7% (pid 200)"))
        #expect(text.contains("3. Finder 5.1% (pid 300)"))
    }

    @Test func processesClipboardTextEmptyProcesses() {
        let m = Self.sampleMetrics(topProcesses: [])
        let text = ProcessesSection.clipboardText(m)
        #expect(text.contains("No data"))
    }

    @Test func processesClipboardTextLimitsToThree() {
        let procs = (0..<5).map {
            ProcessMetric(
                id: Int32($0), name: "P\($0)",
                cpuPercent: Double(50 - $0 * 10)
            )
        }
        let m = Self.sampleMetrics(topProcesses: procs)
        let text = ProcessesSection.clipboardText(m)
        // Should show only first 3
        #expect(text.contains("1. P0"))
        #expect(text.contains("2. P1"))
        #expect(text.contains("3. P2"))
        #expect(!text.contains("4. P3"))
    }
}
