import IOKit.ps
import Testing
@testable import OwlCore

@Suite("BatteryProvider")
struct BatteryProviderTests {

    @Test func buildMetricsUsesBatteryPropertySnapshot() {
        let description: [String: Any] = [
            kIOPSCurrentCapacityKey: 80,
            kIOPSMaxCapacityKey: 4000,
            kIOPSDesignCapacityKey: 5000,
            kIOPSIsChargingKey: true,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue
        ]
        let batteryProperties: [String: Any] = [
            "Temperature": 3150,
            "CycleCount": 123,
            "Voltage": 12000,
            "Amperage": -2000
        ]

        let metrics = BatteryProvider.buildMetrics(
            description: description,
            batteryProperties: batteryProperties,
            timeRemaining: 45
        )

        #expect(metrics.level == 80)
        #expect(metrics.health == 80)
        #expect(metrics.cycleCount == 123)
        #expect(metrics.isCharging)
        #expect(metrics.isPluggedIn)
        #expect(metrics.temperature == 31.5)
        #expect(metrics.timeRemaining == 45)
        #expect(metrics.wattage == 24)
    }

    @Test func buildMetricsClampsHealthAndDefaultsCondition() {
        let description: [String: Any] = [
            kIOPSCurrentCapacityKey: 55,
            kIOPSMaxCapacityKey: 6000,
            kIOPSDesignCapacityKey: 5000,
            kIOPSIsChargingKey: false,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue
        ]

        let metrics = BatteryProvider.buildMetrics(
            description: description,
            batteryProperties: [:],
            timeRemaining: nil
        )

        #expect(metrics.health == 100)
        #expect(metrics.condition == "Normal")
        #expect(!metrics.isCharging)
        #expect(!metrics.isPluggedIn)
        #expect(metrics.temperature == nil)
        #expect(metrics.wattage == nil)
    }
}
