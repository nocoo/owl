import Foundation
@testable import OwlCore

/// Real log samples from macOS unified log stream for testing pattern detectors.
enum TestFixtures {

    // MARK: - Helper

    static func makeEntry(
        message: String,
        timestamp: Date = Date(),
        process: String = "kernel",
        processID: Int = 0,
        subsystem: String = "",
        category: String = ""
    ) -> LogEntry {
        LogEntry(
            timestamp: timestamp,
            process: process,
            processID: processID,
            subsystem: subsystem,
            category: category,
            messageType: "Default",
            eventMessage: message
        )
    }

    // MARK: - P01 Thermal Throttling

    enum Thermal {
        // swiftlint:disable:next line_length
        static let warning = "setDetailedThermalPowerBudget: current power budget: 4500 (mW), thermal_budget_normal: 8000"
        // swiftlint:disable:next line_length
        static let critical = "setDetailedThermalPowerBudget: current power budget: 2500 (mW), thermal_budget_normal: 8000"
        // swiftlint:disable:next line_length
        static let normal = "setDetailedThermalPowerBudget: current power budget: 8000 (mW), thermal_budget_normal: 8000"
        // swiftlint:disable:next line_length
        static let recovered = "setDetailedThermalPowerBudget: current power budget: 7500 (mW), thermal_budget_normal: 8000"

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "kernel")
        }
    }

    // MARK: - P02 Crash Loop

    enum CrashLoop {
        // swiftlint:disable:next line_length
        static let quit = #"QUIT: pid = 85412, name = "com.example.app", type = application, disposition = [enabled, ...], flags = [none], ..."#
        static let checkin = #"CHECKIN: pid = 85413 matches portless application com.example.app"#

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "launchservicesd")
        }
    }

    // MARK: - P03 APFS Flush Delay

    enum DiskFlush {
        static let warning = "tx_flush: 523 tx in 15.234ms"
        static let critical = "tx_flush: 1024 tx in 150.456ms"
        static let normal = "tx_flush: 100 tx in 3.210ms"

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "kernel", subsystem: "com.apple.apfs")
        }
    }

    // MARK: - P04 WiFi Degradation

    enum WiFi {
        static let weak = "LQM: rssi=-75, snr=22, cca=45, txFail=12, txRetry=8"
        static let veryWeak = "LQM: rssi=-85, snr=10, cca=60, txFail=25, txRetry=15"
        static let good = "LQM: rssi=-55, snr=35, cca=20, txFail=1, txRetry=2"

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "airportd", subsystem: "com.apple.wifi")
        }
    }

    // MARK: - P05 Sandbox Violation

    enum Sandbox {
        static let deny = #"Sandbox: Google Chrome(85321) deny(1) file-read-data /private/var/folders/xx/tmp"#
        // swiftlint:disable:next line_length
        static let systemPolicyDeny = #"System Policy: wdavdaemon(562) deny(1) file-read-data /private/var/folders/g2/6htthtys08v10qxbs_0nxfyr0000gn/0/com.apple.ScreenTimeAgent/Store"#

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "kernel", category: "Sandbox")
        }
    }

    // MARK: - P06 Sleep Assertion Leak

    enum SleepAssertion {
        // swiftlint:disable:next line_length
        static let created = #"Created InternalPreventSleep "com.apple.audio.AppleHDAEngineOutput" 00000001 age:0 id:0x0000000100000482"#
        // swiftlint:disable:next line_length
        static let released = #"Released InternalPreventSleep "com.apple.audio.AppleHDAEngineOutput" 00000001 id:0x0000000100000482"#

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "powerd")
        }
    }

    // MARK: - P07 Crash Signal

    enum CrashSignal {
        static let sigkill = "Service com.apple.some.service exited due to SIGKILL | sent by mach_vm_map_kernel[0]: ..."
        static let sigsegv = "Service com.example.daemon exited due to SIGSEGV | sent by exc handler[0]: ..."
        static let sigabrt = "Service com.example.app exited due to SIGABRT | sent by abort()[85412]: ..."

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "launchd")
        }
    }

    // MARK: - P08 Bluetooth Disconnect

    enum Bluetooth {
        static let disconnect = #"Device disconnected - "AirPods Pro" (AA:BB:CC:DD:EE:FF), reason: 0x13"#

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "bluetoothd")
        }
    }

    // MARK: - P09 TCC Permission

    enum TCC {
        static let denied = "AUTHREQ_RESULT: DENIED, service=kTCCServiceAppleEvents, bundleID=com.example.app, ..."

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "tccd")
        }
    }

    // MARK: - P10 Jetsam

    enum Jetsam {
        // swiftlint:disable:next line_length
        static let kill = "memorystatus_kill_top_process: killing pid 85412 [SomeApp] (memorystatus_available_pages: 1024) ..."

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "kernel", category: "memorystatus")
        }
    }

    // MARK: - P11 App Hang

    enum AppHang {
        static let hang = "[pid=85412] failed to act on a ping. Removing"

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "WindowServer")
        }
    }

    // MARK: - P12 Network Failure

    enum Network {
        // swiftlint:disable:next line_length
        static let failed = "nw_connection_report_state_with_handler [C123] reporting state failed error Path:Unsatisfied"

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(
                message: msg,
                timestamp: timestamp,
                process: "nsurlsessiond",
                subsystem: "com.apple.network"
            )
        }
    }

    // MARK: - P13 USB Error

    enum USB {
        // swiftlint:disable:next line_length
        static let abort = "AppleUSBHostController@01000000: IOUSBHostPipe::abortGated: device 0x12345678, endpoint 0x81"

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "kernel", subsystem: "com.apple.iokit")
        }
    }

    // MARK: - P14 DarkWake

    enum DarkWake {
        static let wake = "DarkWake from Normal Sleep [CDNPB] due to EC.LidOpen/Lid Open: Using AC"
        // swiftlint:disable:next line_length
        static let deepIdle = "DarkWake from Deep Idle [CDNP] : due to smc.sysState.Wake wifibt SMC.OutboxNotEmpty"
        // Internal kernel power management status log (NOT a real DarkWake event)
        // swiftlint:disable:next line_length
        static let pmrdNoise = "PMRD: DarkWake: sleepASAP 1, clamshell closed 0, idleSleepEnabled 1"
        // IODisplayPortFamily GPU crossbar status log (NOT a real DarkWake event)
        static let gpuNoise = "checkPMforDarkWake: enter dark wake state"

        static func entry(_ msg: String, timestamp: Date = Date()) -> LogEntry {
            makeEntry(message: msg, timestamp: timestamp, process: "kernel")
        }
    }
}
