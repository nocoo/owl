import Foundation
import Testing
@testable import OwlCore

// MARK: - Live HID Sensor Tests (Apple Silicon only)

@Suite("HIDTemperatureProvider")
struct HIDTemperatureProviderTests {

    let provider = HIDTemperatureProvider()

    // MARK: - Availability

    @Test func isAvailableOnAppleSilicon() {
        #if arch(arm64)
        #expect(provider.isAvailable())
        #else
        #expect(!provider.isAvailable())
        #endif
    }

    // MARK: - CPU / Die Temperature

    @Test func cpuTemperatureReturnsPlausibleValue() {
        #if arch(arm64)
        let temp = provider.cpuTemperature()
        #expect(temp != nil)
        if let temp = temp {
            #expect(temp > 10, "CPU temp \(temp)°C is implausibly low")
            #expect(temp < 120, "CPU temp \(temp)°C is implausibly high")
        }
        #else
        #expect(provider.cpuTemperature() == nil)
        #endif
    }

    @Test func cpuTemperatureMaxIsAtLeastAverage() {
        #if arch(arm64)
        guard let avg = provider.cpuTemperature(),
              let max = provider.cpuTemperatureMax() else {
            Issue.record("Expected CPU temp to be available on arm64")
            return
        }
        #expect(max >= avg, "Max \(max) should be >= avg \(avg)")
        #endif
    }

    @Test func dieSensorsReturnMultipleCores() {
        #if arch(arm64)
        let sensors = provider.dieSensors()
        #expect(sensors.count >= 2,
                "Expected multiple die sensors, got \(sensors.count)")
        // All should match a known die prefix
        for sensor in sensors {
            #expect(
                HIDTemperatureProvider.isDieSensor(sensor.name),
                "\(sensor.name) does not match any die sensor prefix"
            )
        }
        #endif
    }

    // MARK: - All Temperatures

    @Test func allTemperaturesReturnsMultipleSensors() {
        #if arch(arm64)
        let all = provider.allTemperatures()
        #expect(all.count >= 5,
                "Expected at least 5 sensors, got \(all.count)")
        // All values should be plausible
        for (name, celsius) in all {
            #expect(celsius > 0 && celsius < 150,
                    "\(name) has implausible temp \(celsius)°C")
        }
        #endif
    }

    @Test func allTemperaturesAreSortedByName() {
        #if arch(arm64)
        let all = provider.allTemperatures()
        let names = all.map(\.0)
        #expect(names == names.sorted(),
                "Sensor names should be sorted alphabetically")
        #endif
    }

    // MARK: - Stability (rapid reads should not flicker)

    @Test func cpuTemperatureIsStableAcrossRapidReads() {
        #if arch(arm64)
        var readings: [Double] = []
        for _ in 0..<10 {
            if let temp = provider.cpuTemperature() {
                readings.append(temp)
            }
        }
        #expect(readings.count == 10,
                "All 10 rapid reads should succeed")

        // No reading should be wildly different (±30°C) from the first
        if let first = readings.first {
            for (i, reading) in readings.enumerated() {
                #expect(abs(reading - first) < 30,
                        "Reading[\(i)] = \(reading) deviates too much from first = \(first)")
            }
        }
        #endif
    }

    // MARK: - isDieSensor classification

    @Test func isDieSensorMatchesM1M2Names() {
        #expect(HIDTemperatureProvider.isDieSensor("pACC MTR Temp Sensor0"))
        #expect(HIDTemperatureProvider.isDieSensor("pACC MTR Temp Sensor7"))
        #expect(HIDTemperatureProvider.isDieSensor("eACC MTR Temp Sensor0"))
        #expect(HIDTemperatureProvider.isDieSensor("eACC MTR Temp Sensor3"))
    }

    @Test func isDieSensorMatchesM4Names() {
        #expect(HIDTemperatureProvider.isDieSensor("PMU tdie1"))
        #expect(HIDTemperatureProvider.isDieSensor("PMU tdie10"))
    }

    @Test func isDieSensorRejectsNonDieSensors() {
        #expect(!HIDTemperatureProvider.isDieSensor("PMU tdev1"))
        #expect(!HIDTemperatureProvider.isDieSensor("PMU tcal"))
        #expect(!HIDTemperatureProvider.isDieSensor("NAND CH0 temp"))
        #expect(!HIDTemperatureProvider.isDieSensor("gas gauge battery"))
        #expect(!HIDTemperatureProvider.isDieSensor("GPU MTR Temp Sensor0"))
        #expect(!HIDTemperatureProvider.isDieSensor("SOC MTR Temp Sensor0"))
    }

    // MARK: - Die prefix constants

    @Test func diePrefixesContainAllGenerations() {
        let prefixes = HIDTemperatureProvider.diePrefixes
        #expect(prefixes.contains("pACC MTR Temp"))
        #expect(prefixes.contains("eACC MTR Temp"))
        #expect(prefixes.contains("PMU tdie"))
    }

    @Test func gpuPrefixesConfigured() {
        let prefixes = HIDTemperatureProvider.gpuPrefixes
        #expect(prefixes.contains("GPU MTR Temp"))
    }

    @Test func cpuTemperatureFromReadingsAveragesOnlyDieSensors() {
        let readings: [String: Double] = [
            "pACC MTR Temp Sensor0": 52,
            "eACC MTR Temp Sensor1": 48,
            "GPU MTR Temp Sensor0": 70,
            "PMU tdev1": 66,
            "PMU tdie2": 60
        ]

        let temp = HIDTemperatureProvider.cpuTemperature(from: readings)
        #expect(temp == 160.0 / 3.0)
    }

    @Test func gpuTemperatureFromReadingsUsesOnlyGPUSensors() {
        let readings: [String: Double] = [
            "pACC MTR Temp Sensor0": 52,
            "GPU MTR Temp Sensor0": 70,
            "GPU MTR Temp Sensor1": 74,
            "PMU tdev1": 66
        ]

        let temp = HIDTemperatureProvider.gpuTemperature(from: readings)
        #expect(temp == 72)
    }
}
