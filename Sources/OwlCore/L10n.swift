import Foundation

// MARK: - Language

/// Supported languages for the Owl UI.
public enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case en
    case zh

    public var displayName: String {
        switch self {
        case .system: return L10n.tr(.followSystem)
        case .en: return "English"
        case .zh: return "中文"
        }
    }

    /// Resolve to a concrete language (en or zh).
    public var resolved: AppLanguage {
        if self != .system { return self }
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh") { return .zh }
        return .en
    }
}

// MARK: - Appearance

/// Appearance mode preference.
public enum AppAppearance: String, CaseIterable, Sendable {
    case auto
    case light
    case dark

    public var displayName: String {
        switch self {
        case .auto: return L10n.tr(.appearanceAuto)
        case .light: return L10n.tr(.appearanceLight)
        case .dark: return L10n.tr(.appearanceDark)
        }
    }
}

// MARK: - L10n Keys

/// All localizable string keys used across the Owl UI.
public enum L10nKey: Sendable {
    // App
    case appName
    case systemHealthMonitor
    case followSystem

    // Severity
    case severityNormal
    case severityInfo
    case severityWarning
    case severityCritical

    // Popover sections
    case sectionCPU
    case sectionMemory
    case sectionDisk
    case sectionPower
    case sectionTemperature
    case sectionNetwork
    case sectionTopProcesses

    // CPU
    case cpuTotal
    case cpuPCores
    case cpuECores
    case cpuCores
    case cpuLoad

    // Memory
    case memUsed
    case memFree
    case memTotal
    case memCache
    case memAvail
    case memSwap
    case memPageIn
    case memPageOut

    // Disk
    case diskINTR
    case diskRead
    case diskWrite
    case diskAvail
    case diskTotal

    // Power
    case powerLevel
    case powerHealth
    case powerCycles
    case powerCond
    case powerState
    case powerCharging
    case powerPlugged
    case powerBattery
    case powerUnavailable
    case powerNA
    case powerNormal

    // Temperature (no extra keys needed — sensor labels are dynamic)

    // Network
    case netDown
    case netUp
    case netIP
    case netWiFi
    case netEthernet(String)
    case netTUN(String)

    // Processes
    case noData

    // Alerts
    case activeAlerts
    case totalCount(Int)
    case systemRunningNormally
    case noAnomaliesDetected
    case recentEvents
    case copied
    case justNow
    case minutesAgo(Int)
    case hoursAgo(Int)

    // Alerts tab (settings)
    case noAlerts
    case systemRunningNormallyShort
    case sectionActive
    case sectionRecentHistory

    // Bottom bar
    case settings
    case quit

    // Settings tabs
    case tabGeneral
    case tabDetectors
    case tabAlerts
    case tabProcesses

    // General tab
    case sectionAbout
    case sectionStartup
    case sectionMonitoring
    case launchAtLogin
    case refreshInterval
    case refreshIntervalValue
    case logBufferSize
    case logBufferSizeValue

    // Appearance
    case sectionAppearance
    case appearanceAuto
    case appearanceLight
    case appearanceDark
    case appearanceMode

    // Language
    case sectionLanguage
    case language

    // Process tab
    case systemUptime
    case bootedAt(String)
    case collectingProcessData
    case tableRank
    case tableProcess
    case tableCPUTime
    case tableMemory
    case tableInstances

    // Settings window
    case settingsWindowTitle

    // Context menu
    case contextSettings
    case contextQuit

    // Clipboard
    case clipboardSuggestion(String)
    case clipboardDetector(String, String)

    // Battery stateText (model)
    case batteryCharging
    case batteryPluggedIn
    case batteryDischarging

    // DetectorCatalog categories
    case catHardware
    case catMemory
    case catPower
    case catNetwork
    case catSecurity
    case catProcess

    // DetectorCatalog entries (displayName, description)
    case detectorThermalThrottling
    case detectorThermalThrottlingDesc
    case detectorUSBDeviceError
    case detectorUSBDeviceErrorDesc
    case detectorAPFSFlushDelay
    case detectorAPFSFlushDelayDesc
    case detectorJetsamKill
    case detectorJetsamKillDesc
    case detectorJetsamEscalation
    case detectorJetsamEscalationDesc
    case detectorSleepAssertionLeak
    case detectorSleepAssertionLeakDesc
    case detectorDarkWake
    case detectorDarkWakeDesc
    case detectorWiFiDegradation
    case detectorWiFiDegradationDesc
    case detectorBluetoothDisconnect
    case detectorBluetoothDisconnectDesc
    case detectorNetworkFailure
    case detectorNetworkFailureDesc
    case detectorSandboxViolation
    case detectorSandboxViolationDesc
    case detectorTCCPermissionStorm
    case detectorTCCPermissionStormDesc
    case detectorProcessCrashLoop
    case detectorProcessCrashLoopDesc
    case detectorCrashSignal
    case detectorCrashSignalDesc
    case detectorAppHang
    case detectorAppHangDesc

    // Pattern alert strings (title / description / suggestion)
    case alertThermalTitle
    case alertThermalDesc(String)
    case alertThermalSuggestion
    case alertUSBTitle
    case alertUSBDesc(String, String, String)
    case alertUSBSuggestion
    case alertDiskFlushTitle
    case alertDiskFlushDesc(String)
    case alertDiskFlushSuggestion
    case alertJetsamTitle
    case alertJetsamDesc(String)
    case alertJetsamSuggestion
    case alertJetsamEscTitle
    case alertJetsamEscDesc(String)
    case alertJetsamEscSuggestion
    case alertSleepTitle
    case alertSleepDesc(String, String, String, String)
    case alertSleepSuggestion
    case alertDarkWakeTitle
    case alertDarkWakeDesc(String, String)
    case alertDarkWakeSuggestion
    case alertWiFiTitle
    case alertWiFiDesc(String)
    case alertWiFiSuggestion
    case alertBluetoothTitle
    case alertBluetoothDesc(String, String, String)
    case alertBluetoothSuggestion
    case alertNetworkTitle
    case alertNetworkDesc(String, String)
    case alertNetworkSuggestion
    case alertSandboxTitle
    case alertSandboxDesc(String, String, String)
    case alertSandboxSuggestion
    case alertTCCTitle
    case alertTCCDesc(String, String, String)
    case alertTCCSuggestion
    case alertCrashLoopTitle
    case alertCrashLoopDesc(String, String, String)
    case alertCrashLoopSuggestion
    case alertCrashSignalTitle
    case alertCrashSignalDesc(String, String, String)
    case alertCrashSignalSuggestion
    case alertAppHangTitle
    case alertAppHangDesc(String, String, String)
    case alertAppHangSuggestion

    // Recovery / global
    case alertRecoveredSuffix
    case alertRecoveredDesc
    case alertGlobalSystem
}

// MARK: - L10n Translation Engine

/// Centralized localization engine. Uses a pure-Swift string table
/// (no .strings files) for compile-time safety and runtime switching.
public enum L10n {

    /// Current resolved language. Observe via `NotificationCenter`
    /// with `L10n.didChangeNotification`.
    public private(set) static var current: AppLanguage = .en

    /// Posted when the active language changes.
    public static let didChangeNotification = Notification.Name(
        "owl.l10n.didChange"
    )

    /// Set the active language and broadcast change.
    public static func setLanguage(_ lang: AppLanguage) {
        let resolved = lang.resolved
        guard resolved != current else { return }
        current = resolved
        NotificationCenter.default.post(
            name: didChangeNotification, object: nil
        )
    }

    /// Bootstrap: resolve initial language from preference.
    public static func bootstrap(preference: AppLanguage) {
        current = preference.resolved
    }

    /// Translate a key using the current language.
    public static func tr(_ key: L10nKey) -> String {
        translate(key, lang: current)
    }

    // MARK: - String Tables

    static func translate(
        _ key: L10nKey, lang: AppLanguage
    ) -> String {
        switch lang {
        case .zh: return zh(key)
        case .en, .system: return en(key)
        }
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    private static func en(_ key: L10nKey) -> String {
        switch key {
        // App
        case .appName: return "Owl"
        case .systemHealthMonitor: return "System Health Monitor"
        case .followSystem: return "Follow System"

        // Severity
        case .severityNormal: return "Normal"
        case .severityInfo: return "Info"
        case .severityWarning: return "Warning"
        case .severityCritical: return "Critical"

        // Sections
        case .sectionCPU: return "CPU"
        case .sectionMemory: return "Memory"
        case .sectionDisk: return "Disk"
        case .sectionPower: return "Power"
        case .sectionTemperature: return "Temperature"
        case .sectionNetwork: return "Network"
        case .sectionTopProcesses: return "Top Processes"

        // CPU
        case .cpuTotal: return "Total"
        case .cpuPCores: return "P-Cores"
        case .cpuECores: return "E-Cores"
        case .cpuCores: return "Cores"
        case .cpuLoad: return "Load"

        // Memory
        case .memUsed: return "Used"
        case .memFree: return "Free"
        case .memTotal: return "Total"
        case .memCache: return "Cache"
        case .memAvail: return "Avail"
        case .memSwap: return "Swap"
        case .memPageIn: return "PgIn"
        case .memPageOut: return "PgOut"

        // Disk
        case .diskINTR: return "INTR"
        case .diskRead: return "Read"
        case .diskWrite: return "Write"
        case .diskAvail: return "Avail"
        case .diskTotal: return "Total"

        // Power
        case .powerLevel: return "Level"
        case .powerHealth: return "Health"
        case .powerCycles: return "Cycles"
        case .powerCond: return "Cond"
        case .powerState: return "State"
        case .powerCharging: return "Charging"
        case .powerPlugged: return "Plugged"
        case .powerBattery: return "Battery"
        case .powerUnavailable: return "Unavailable"
        case .powerNA: return "N/A"
        case .powerNormal: return "Normal"

        // Network
        case .netDown: return "Down"
        case .netUp: return "Up"
        case .netIP: return "IP"
        case .netWiFi: return "Wi-Fi"
        case .netEthernet(let name): return "Ethernet \(name)"
        case .netTUN(let name): return "TUN \(name)"

        // Processes
        case .noData: return "No data"

        // Alerts
        case .activeAlerts: return "Active Alerts"
        case .totalCount(let n): return "\(n) total"
        case .systemRunningNormally:
            return "System Running Normally"
        case .noAnomaliesDetected:
            return "No anomalies detected"
        case .recentEvents: return "Recent Events"
        case .copied: return "Copied"
        case .justNow: return "just now"
        case .minutesAgo(let m): return "\(m)m ago"
        case .hoursAgo(let h): return "\(h)h ago"

        // Alerts tab
        case .noAlerts: return "No Alerts"
        case .systemRunningNormallyShort:
            return "System is running normally"
        case .sectionActive: return "Active"
        case .sectionRecentHistory: return "Recent History"

        // Bottom bar
        case .settings: return "Settings"
        case .quit: return "Quit"

        // Settings tabs
        case .tabGeneral: return "General"
        case .tabDetectors: return "Detectors"
        case .tabAlerts: return "Alerts"
        case .tabProcesses: return "Processes"

        // General tab
        case .sectionAbout: return "About"
        case .sectionStartup: return "Startup"
        case .sectionMonitoring: return "Monitoring"
        case .launchAtLogin: return "Launch at Login"
        case .refreshInterval: return "Refresh Interval"
        case .refreshIntervalValue: return "1 second"
        case .logBufferSize: return "Log Buffer Size"
        case .logBufferSizeValue: return "256 entries"

        // Appearance
        case .sectionAppearance: return "Appearance"
        case .appearanceAuto: return "Auto"
        case .appearanceLight: return "Light"
        case .appearanceDark: return "Dark"
        case .appearanceMode: return "Appearance Mode"

        // Language
        case .sectionLanguage: return "Language"
        case .language: return "Language"

        // Process tab
        case .systemUptime: return "System Uptime"
        case .bootedAt(let t): return "Booted \(t)"
        case .collectingProcessData:
            return "Collecting process data…"
        case .tableRank: return "#"
        case .tableProcess: return "Process"
        case .tableCPUTime: return "CPU Time"
        case .tableMemory: return "Memory"
        case .tableInstances: return "N"

        // Settings window
        case .settingsWindowTitle: return "Owl Settings"

        // Context menu
        case .contextSettings: return "Settings..."
        case .contextQuit: return "Quit Owl"

        // Clipboard
        case .clipboardSuggestion(let s):
            return "Suggestion: \(s)"
        case .clipboardDetector(let id, let ts):
            return "Detector: \(id) | \(ts)"

        // Battery model
        case .batteryCharging: return "Charging"
        case .batteryPluggedIn: return "Plugged In"
        case .batteryDischarging: return "Discharging"

        // Detector categories
        case .catHardware: return "Hardware"
        case .catMemory: return "Memory"
        case .catPower: return "Power"
        case .catNetwork: return "Network"
        case .catSecurity: return "Security"
        case .catProcess: return "Process"

        // Detector catalog
        case .detectorThermalThrottling:
            return "Thermal Throttling"
        case .detectorThermalThrottlingDesc:
            return "CPU power budget reduction"
        case .detectorUSBDeviceError:
            return "USB Device Error"
        case .detectorUSBDeviceErrorDesc:
            return "USB device transfer errors"
        case .detectorAPFSFlushDelay:
            return "APFS Flush Delay"
        case .detectorAPFSFlushDelayDesc:
            return "Disk write flush too slow"
        case .detectorJetsamKill:
            return "Jetsam Memory Kill"
        case .detectorJetsamKillDesc:
            return "Process killed for memory"
        case .detectorJetsamEscalation:
            return "Jetsam Escalation"
        case .detectorJetsamEscalationDesc:
            return "Rapid jetsam kills"
        case .detectorSleepAssertionLeak:
            return "Sleep Assertion Leak"
        case .detectorSleepAssertionLeakDesc:
            return "Unreleased sleep assertions"
        case .detectorDarkWake:
            return "Dark Wake"
        case .detectorDarkWakeDesc:
            return "Excessive background wakes"
        case .detectorWiFiDegradation:
            return "WiFi Degradation"
        case .detectorWiFiDegradationDesc:
            return "WiFi RSSI below threshold"
        case .detectorBluetoothDisconnect:
            return "Bluetooth Disconnect"
        case .detectorBluetoothDisconnectDesc:
            return "Repeated disconnections"
        case .detectorNetworkFailure:
            return "Network Failure"
        case .detectorNetworkFailureDesc:
            return "Connection failures"
        case .detectorSandboxViolation:
            return "Sandbox Violation"
        case .detectorSandboxViolationDesc:
            return "Access denial storm"
        case .detectorTCCPermissionStorm:
            return "TCC Permission Storm"
        case .detectorTCCPermissionStormDesc:
            return "Privacy permission denials"
        case .detectorProcessCrashLoop:
            return "Process Crash Loop"
        case .detectorProcessCrashLoopDesc:
            return "Repeated process crashes"
        case .detectorCrashSignal:
            return "Crash Signal"
        case .detectorCrashSignalDesc:
            return "SEGFAULT, SIGBUS, etc."
        case .detectorAppHang:
            return "App Hang"
        case .detectorAppHangDesc:
            return "Application unresponsive"

        // Pattern alerts
        case .alertThermalTitle:
            return "CPU Thermal Throttling"
        case .alertThermalDesc(let val):
            return "Current power budget \(val) mW, system throttling"
        case .alertThermalSuggestion:
            return "Check for CPU-heavy processes (Activity Monitor), ensure vents are unobstructed"
        case .alertUSBTitle:
            return "USB Device Communication Error"
        case .alertUSBDesc(let key, let window, let count):
            return "Device \(key) had \(count) transfer interruptions in the past \(window)s"
        case .alertUSBSuggestion:
            return "Try re-plugging the USB device, or replace the cable/port"
        case .alertDiskFlushTitle:
            return "Disk I/O Latency Elevated"
        case .alertDiskFlushDesc(let val):
            return "APFS flush took \(val) ms (normal < 10 ms)"
        case .alertDiskFlushSuggestion:
            return "Check disk health (Disk Utility → First Aid), ensure no heavy write operations"
        case .alertJetsamTitle:
            return "System Memory Pressure"
        case .alertJetsamDesc(let val):
            return "macOS terminated a process due to memory pressure (PID \(val))"
        case .alertJetsamSuggestion:
            return "Close unnecessary apps to free memory, or consider restarting"
        case .alertJetsamEscTitle:
            return "Severe Memory Pressure"
        case .alertJetsamEscDesc(let count):
            return "\(count) processes terminated by Jetsam in 5 minutes"
        case .alertJetsamEscSuggestion:
            return "Close unnecessary apps to free memory, or consider restarting"
        case .alertSleepTitle:
            return "Sleep Assertion Unreleased"
        case .alertSleepDesc(let id, let type, let source, let age):
            return "Assertion \(id) (\(type)) from \"\(source)\" held for \(age) seconds"
        case .alertSleepSuggestion:
            return "Run pmset -g assertions to check current sleep assertions, or restart the process"
        case .alertDarkWakeTitle:
            return "Frequent System Wakes"
        case .alertDarkWakeDesc(let count, let window):
            return "\(count) DarkWake events in the past \(window) seconds"
        case .alertDarkWakeSuggestion:
            return "Run pmset -g log | grep DarkWake to view detailed wake records"
        case .alertWiFiTitle:
            return "Weak WiFi Signal"
        case .alertWiFiDesc(let val):
            return "Current signal strength \(val) dBm"
        case .alertWiFiSuggestion:
            return "Try moving closer to the router, or switch to the 5 GHz band"
        case .alertBluetoothTitle:
            return "Bluetooth Device Disconnecting"
        case .alertBluetoothDesc(let key, let window, let count):
            return "\(key) disconnected \(count) times in the past \(window)s"
        case .alertBluetoothSuggestion:
            return "Try re-pairing the device, or check if its battery is low"
        case .alertNetworkTitle:
            return "Network Connection Issues"
        case .alertNetworkDesc(let count, let window):
            return "\(count) connection failures in the past \(window) seconds"
        case .alertNetworkSuggestion:
            return "Check WiFi and VPN connections, try opening a browser to test"
        case .alertSandboxTitle:
            return "Sandbox Violation Storm"
        case .alertSandboxDesc(let key, let window, let count):
            return "\(key) was denied \(count) times in the past \(window)s"
        case .alertSandboxSuggestion:
            return "Usually an app compatibility issue; try reinstalling the app or checking permissions"
        case .alertTCCTitle:
            return "Permission Requests Denied"
        case .alertTCCDesc(let key, let window, let count):
            return "\(key) permission denied \(count) times in the past \(window)s"
        case .alertTCCSuggestion:
            return "Check the app's permissions in System Settings → Privacy & Security"
        case .alertCrashLoopTitle:
            return "Process Crash Loop"
        case .alertCrashLoopDesc(let key, let window, let count):
            return "\(key) crashed \(count) times in the past \(window)s"
        case .alertCrashLoopSuggestion:
            return "Try force-quitting the process in Activity Monitor, or check its configuration"
        case .alertCrashSignalTitle:
            return "Process Crash Signal"
        case .alertCrashSignalDesc(
            let key, let window, let count
        ):
            return "\(key) exited via signal \(count) times in the past \(window)s"
        case .alertCrashSignalSuggestion:
            return "Check ~/Library/Logs/DiagnosticReports/ for crash reports"
        case .alertAppHangTitle:
            return "Application Not Responding"
        case .alertAppHangDesc(let key, let count, let window):
            return "PID \(key) failed WindowServer heartbeat (\(count) times/\(window)s)"
        case .alertAppHangSuggestion:
            return "Check the process in Activity Monitor, try force-quitting"

        // Recovery / global
        case .alertRecoveredSuffix: return "Recovered"
        case .alertRecoveredDesc: return "System has returned to normal"
        case .alertGlobalSystem: return "system"
        }
    }

    private static func zh(_ key: L10nKey) -> String {
        switch key {
        // App
        case .appName: return "Owl"
        case .systemHealthMonitor: return "系统健康监视器"
        case .followSystem: return "跟随系统"

        // Severity
        case .severityNormal: return "正常"
        case .severityInfo: return "信息"
        case .severityWarning: return "警告"
        case .severityCritical: return "严重"

        // Sections
        case .sectionCPU: return "CPU"
        case .sectionMemory: return "内存"
        case .sectionDisk: return "磁盘"
        case .sectionPower: return "电源"
        case .sectionTemperature: return "温度"
        case .sectionNetwork: return "网络"
        case .sectionTopProcesses: return "活跃进程"

        // CPU
        case .cpuTotal: return "总计"
        case .cpuPCores: return "性能核"
        case .cpuECores: return "能效核"
        case .cpuCores: return "核心"
        case .cpuLoad: return "负载"

        // Memory
        case .memUsed: return "已用"
        case .memFree: return "空闲"
        case .memTotal: return "总计"
        case .memCache: return "缓存"
        case .memAvail: return "可用"
        case .memSwap: return "交换"
        case .memPageIn: return "换入"
        case .memPageOut: return "换出"

        // Disk
        case .diskINTR: return "内置"
        case .diskRead: return "读取"
        case .diskWrite: return "写入"
        case .diskAvail: return "可用"
        case .diskTotal: return "总计"

        // Power
        case .powerLevel: return "电量"
        case .powerHealth: return "健康"
        case .powerCycles: return "循环"
        case .powerCond: return "状态"
        case .powerState: return "状态"
        case .powerCharging: return "充电中"
        case .powerPlugged: return "已接入"
        case .powerBattery: return "电池"
        case .powerUnavailable: return "不可用"
        case .powerNA: return "N/A"
        case .powerNormal: return "正常"

        // Network
        case .netDown: return "下行"
        case .netUp: return "上行"
        case .netIP: return "IP"
        case .netWiFi: return "Wi-Fi"
        case .netEthernet(let name): return "以太网 \(name)"
        case .netTUN(let name): return "TUN \(name)"

        // Processes
        case .noData: return "暂无数据"

        // Alerts
        case .activeAlerts: return "活跃告警"
        case .totalCount(let n): return "共 \(n) 条"
        case .systemRunningNormally: return "系统运行正常"
        case .noAnomaliesDetected: return "未检测到异常"
        case .recentEvents: return "近期事件"
        case .copied: return "已复制"
        case .justNow: return "刚刚"
        case .minutesAgo(let m): return "\(m) 分钟前"
        case .hoursAgo(let h): return "\(h) 小时前"

        // Alerts tab
        case .noAlerts: return "没有告警"
        case .systemRunningNormallyShort: return "系统运行正常"
        case .sectionActive: return "活跃"
        case .sectionRecentHistory: return "近期历史"

        // Bottom bar
        case .settings: return "设置"
        case .quit: return "退出"

        // Settings tabs
        case .tabGeneral: return "通用"
        case .tabDetectors: return "检测器"
        case .tabAlerts: return "告警"
        case .tabProcesses: return "进程"

        // General tab
        case .sectionAbout: return "关于"
        case .sectionStartup: return "启动"
        case .sectionMonitoring: return "监控"
        case .launchAtLogin: return "开机启动"
        case .refreshInterval: return "刷新间隔"
        case .refreshIntervalValue: return "1 秒"
        case .logBufferSize: return "日志缓冲"
        case .logBufferSizeValue: return "256 条"

        // Appearance
        case .sectionAppearance: return "外观"
        case .appearanceAuto: return "自动"
        case .appearanceLight: return "浅色"
        case .appearanceDark: return "深色"
        case .appearanceMode: return "外观模式"

        // Language
        case .sectionLanguage: return "语言"
        case .language: return "语言"

        // Process tab
        case .systemUptime: return "系统运行时间"
        case .bootedAt(let t): return "启动于 \(t)"
        case .collectingProcessData: return "正在收集进程数据…"
        case .tableRank: return "#"
        case .tableProcess: return "进程"
        case .tableCPUTime: return "CPU 时间"
        case .tableMemory: return "内存"
        case .tableInstances: return "N"

        // Settings window
        case .settingsWindowTitle: return "Owl 设置"

        // Context menu
        case .contextSettings: return "设置..."
        case .contextQuit: return "退出 Owl"

        // Clipboard
        case .clipboardSuggestion(let s): return "建议: \(s)"
        case .clipboardDetector(let id, let ts):
            return "检测器: \(id) | \(ts)"

        // Battery model
        case .batteryCharging: return "充电中"
        case .batteryPluggedIn: return "已接入电源"
        case .batteryDischarging: return "使用电池"

        // Detector categories
        case .catHardware: return "硬件"
        case .catMemory: return "内存"
        case .catPower: return "电源"
        case .catNetwork: return "网络"
        case .catSecurity: return "安全"
        case .catProcess: return "进程"

        // Detector catalog
        case .detectorThermalThrottling: return "温度节流"
        case .detectorThermalThrottlingDesc:
            return "CPU 功率预算降低"
        case .detectorUSBDeviceError: return "USB 设备错误"
        case .detectorUSBDeviceErrorDesc:
            return "USB 设备传输错误"
        case .detectorAPFSFlushDelay: return "APFS 刷写延迟"
        case .detectorAPFSFlushDelayDesc:
            return "磁盘写入刷新过慢"
        case .detectorJetsamKill: return "Jetsam 内存终止"
        case .detectorJetsamKillDesc:
            return "进程因内存不足被终止"
        case .detectorJetsamEscalation: return "Jetsam 升级"
        case .detectorJetsamEscalationDesc:
            return "快速连续的 Jetsam 终止"
        case .detectorSleepAssertionLeak:
            return "Sleep 断言泄漏"
        case .detectorSleepAssertionLeakDesc:
            return "未释放的休眠断言"
        case .detectorDarkWake: return "后台唤醒"
        case .detectorDarkWakeDesc: return "过多的后台唤醒"
        case .detectorWiFiDegradation: return "WiFi 信号衰减"
        case .detectorWiFiDegradationDesc:
            return "WiFi RSSI 低于阈值"
        case .detectorBluetoothDisconnect:
            return "蓝牙断连"
        case .detectorBluetoothDisconnectDesc:
            return "反复断开连接"
        case .detectorNetworkFailure: return "网络故障"
        case .detectorNetworkFailureDesc: return "连接失败"
        case .detectorSandboxViolation: return "沙箱违规"
        case .detectorSandboxViolationDesc:
            return "访问拒绝风暴"
        case .detectorTCCPermissionStorm:
            return "TCC 权限风暴"
        case .detectorTCCPermissionStormDesc:
            return "隐私权限被大量拒绝"
        case .detectorProcessCrashLoop: return "进程崩溃循环"
        case .detectorProcessCrashLoopDesc:
            return "进程反复崩溃"
        case .detectorCrashSignal: return "崩溃信号"
        case .detectorCrashSignalDesc:
            return "SEGFAULT、SIGBUS 等"
        case .detectorAppHang: return "应用无响应"
        case .detectorAppHangDesc: return "应用程序未响应"

        // Pattern alerts
        case .alertThermalTitle: return "CPU 散热节流中"
        case .alertThermalDesc(let val):
            return "当前功率预算 \(val) mW，系统正在降频散热"
        case .alertThermalSuggestion:
            return "检查是否有高 CPU 进程（Activity Monitor），确保通风口畅通"
        case .alertUSBTitle: return "USB 设备通信异常"
        case .alertUSBDesc(let key, let window, let count):
            return "设备 \(key) 在过去 \(window) 秒发生 \(count) 次传输中断"
        case .alertUSBSuggestion:
            return "尝试重新插拔该 USB 设备，或更换 USB 线缆/端口"
        case .alertDiskFlushTitle: return "磁盘 I/O 延迟升高"
        case .alertDiskFlushDesc(let val):
            return "APFS 刷写耗时 \(val) ms（正常 < 10 ms）"
        case .alertDiskFlushSuggestion:
            return "检查磁盘健康状态（Disk Utility → First Aid），确认没有大量写入操作"
        case .alertJetsamTitle: return "系统内存不足"
        case .alertJetsamDesc(let val):
            return "macOS 因内存压力终止了进程（PID \(val)）"
        case .alertJetsamSuggestion:
            return "关闭不必要的应用以释放内存，或考虑重启系统"
        case .alertJetsamEscTitle: return "系统内存严重不足"
        case .alertJetsamEscDesc(let count):
            return "5 分钟内 \(count) 个进程被 Jetsam 终止"
        case .alertJetsamEscSuggestion:
            return "关闭不必要的应用以释放内存，或考虑重启系统"
        case .alertSleepTitle: return "Sleep 断言未释放"
        case .alertSleepDesc(let id, let type, let source, let age):
            return "断言 \(id)（\(type)）来自 \"\(source)\" 已持续 \(age) 秒"
        case .alertSleepSuggestion:
            return "运行 pmset -g assertions 查看当前 sleep 断言，或重启相关进程"
        case .alertDarkWakeTitle: return "系统被频繁唤醒"
        case .alertDarkWakeDesc(let count, let window):
            return "过去 \(window) 秒发生 \(count) 次 DarkWake"
        case .alertDarkWakeSuggestion:
            return "运行 pmset -g log | grep DarkWake 查看详细唤醒记录"
        case .alertWiFiTitle: return "WiFi 信号较弱"
        case .alertWiFiDesc(let val):
            return "当前信号强度 \(val) dBm"
        case .alertWiFiSuggestion:
            return "尝试靠近路由器，或切换到 5GHz 频段"
        case .alertBluetoothTitle: return "蓝牙设备反复断连"
        case .alertBluetoothDesc(
            let key, let window, let count
        ):
            return "\(key) 在过去 \(window) 秒断连了 \(count) 次"
        case .alertBluetoothSuggestion:
            return "尝试重新配对设备，或检查设备电量是否不足"
        case .alertNetworkTitle: return "系统网络连接异常"
        case .alertNetworkDesc(let count, let window):
            return "过去 \(window) 秒有 \(count) 次网络连接失败"
        case .alertNetworkSuggestion:
            return "检查 WiFi 连接状态和 VPN 是否正常，尝试打开浏览器测试网络"
        case .alertSandboxTitle: return "沙箱违规风暴"
        case .alertSandboxDesc(
            let key, let window, let count
        ):
            return "\(key) 在过去 \(window) 秒被拒绝 \(count) 次"
        case .alertSandboxSuggestion:
            return "通常为应用兼容性问题，如频繁发生可尝试重装该应用或检查权限设置"
        case .alertTCCTitle: return "权限请求被大量拒绝"
        case .alertTCCDesc(let key, let window, let count):
            return "\(key) 在过去 \(window) 秒请求权限被拒绝 \(count) 次"
        case .alertTCCSuggestion:
            return "在系统设置 → 隐私与安全中检查该应用的权限配置"
        case .alertCrashLoopTitle: return "进程反复崩溃"
        case .alertCrashLoopDesc(
            let key, let window, let count
        ):
            return "\(key) 在过去 \(window) 秒内崩溃了 \(count) 次"
        case .alertCrashLoopSuggestion:
            return "尝试在 Activity Monitor 中强制退出该进程，或检查其配置是否有误"
        case .alertCrashSignalTitle: return "进程频繁崩溃"
        case .alertCrashSignalDesc(
            let key, let window, let count
        ):
            return "\(key) 在过去 \(window) 秒因信号退出了 \(count) 次"
        case .alertCrashSignalSuggestion:
            return "查看 ~/Library/Logs/DiagnosticReports/ 中对应的 crash 报告"
        case .alertAppHangTitle: return "应用无响应"
        case .alertAppHangDesc(let key, let count, let window):
            return "PID \(key) 未响应 WindowServer 的心跳检测（\(count) 次/\(window)s）"
        case .alertAppHangSuggestion:
            return "在 Activity Monitor 中查看该进程是否正常，可尝试强制退出"

        // Recovery / global
        case .alertRecoveredSuffix: return "已恢复"
        case .alertRecoveredDesc: return "系统已恢复正常"
        case .alertGlobalSystem: return "系统"
        }
    }
    // swiftlint:enable function_body_length cyclomatic_complexity
}
