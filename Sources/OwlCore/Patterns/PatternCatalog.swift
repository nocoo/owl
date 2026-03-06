import Foundation

/// Factory that creates all 14 pattern detectors (15 instances, since P10 Jetsam uses a hybrid pair).
///
/// Use `makeAll()` to get a fresh array of detectors for the pipeline.
/// Each call returns new instances so detector state is not shared.
public enum PatternCatalog {

    /// Creates all pattern detectors. Returns 15 detector instances:
    /// - P01 ThermalPattern (ThresholdDetector)
    /// - P02 CrashLoopPattern (RateDetector)
    /// - P03 DiskFlushPattern (ThresholdDetector)
    /// - P04 WiFiPattern (ThresholdDetector)
    /// - P05 SandboxPattern (RateDetector)
    /// - P06 SleepAssertionPattern (StateDetector)
    /// - P07 CrashSignalPattern (RateDetector)
    /// - P08 BluetoothPattern (RateDetector)
    /// - P09 TCCPattern (RateDetector)
    /// - P10 JetsamPattern (ThresholdDetector + RateDetector)
    /// - P11 AppHangPattern (RateDetector)
    /// - P12 NetworkPattern (RateDetector)
    /// - P13 USBPattern (RateDetector)
    /// - P14 DarkWakePattern (RateDetector)
    public static func makeAll() -> [PatternDetector] {
        [
            ThermalPattern.makeDetector(),
            CrashLoopPattern.makeDetector(),
            DiskFlushPattern.makeDetector(),
            WiFiPattern.makeDetector(),
            SandboxPattern.makeDetector(),
            SleepAssertionPattern.makeDetector(),
            CrashSignalPattern.makeDetector(),
            BluetoothPattern.makeDetector(),
            TCCPattern.makeDetector(),
            JetsamPattern.makeDetector(),
            JetsamPattern.makeEscalationDetector(),
            AppHangPattern.makeDetector(),
            NetworkPattern.makeDetector(),
            USBPattern.makeDetector(),
            DarkWakePattern.makeDetector()
        ]
    }
}
