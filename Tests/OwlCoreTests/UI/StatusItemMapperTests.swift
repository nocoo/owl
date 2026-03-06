import Testing
@testable import OwlCore

@Suite("StatusItemMapper")
struct StatusItemMapperTests {

    // MARK: - Normal State

    @Test func normalUsesBirdSymbol() {
        let config = StatusItemMapper.config(for: .normal)
        #expect(config.symbolName == "bird")
        #expect(config.isFilled == false)
    }

    @Test func normalUsesDefaultColor() {
        let config = StatusItemMapper.config(for: .normal)
        #expect(config.colorName == .default)
    }

    @Test func normalDoesNotPulse() {
        let config = StatusItemMapper.config(for: .normal)
        #expect(config.shouldPulse == false)
    }

    // MARK: - Info State

    @Test func infoUsesBirdSymbolWithBlue() {
        let config = StatusItemMapper.config(for: .info)
        #expect(config.symbolName == "bird")
        #expect(config.isFilled == false)
        #expect(config.colorName == .blue)
    }

    // MARK: - Warning State

    @Test func warningUsesFilledBirdWithYellow() {
        let config = StatusItemMapper.config(for: .warning)
        #expect(config.symbolName == "bird.fill")
        #expect(config.isFilled == true)
        #expect(config.colorName == .yellow)
    }

    @Test func warningDoesNotPulse() {
        let config = StatusItemMapper.config(for: .warning)
        #expect(config.shouldPulse == false)
    }

    // MARK: - Critical State

    @Test func criticalUsesFilledBirdWithRed() {
        let config = StatusItemMapper.config(for: .critical)
        #expect(config.symbolName == "bird.fill")
        #expect(config.isFilled == true)
        #expect(config.colorName == .red)
    }

    @Test func criticalPulses() {
        let config = StatusItemMapper.config(for: .critical)
        #expect(config.shouldPulse == true)
    }

    // MARK: - Recovery Detection

    @Test func recoveryFromWarningToNormalShowsGreenFlash() {
        let config = StatusItemMapper.config(
            for: .normal, previousSeverity: .warning
        )
        #expect(config.showRecoveryFlash == true)
        #expect(config.colorName == .green)
    }

    @Test func recoveryFromCriticalToNormalShowsGreenFlash() {
        let config = StatusItemMapper.config(
            for: .normal, previousSeverity: .critical
        )
        #expect(config.showRecoveryFlash == true)
        #expect(config.colorName == .green)
    }

    @Test func recoveryFromCriticalToInfoShowsGreenFlash() {
        let config = StatusItemMapper.config(
            for: .info, previousSeverity: .critical
        )
        #expect(config.showRecoveryFlash == true)
    }

    @Test func noRecoveryWhenPreviousIsNormal() {
        let config = StatusItemMapper.config(
            for: .normal, previousSeverity: .normal
        )
        #expect(config.showRecoveryFlash == false)
        #expect(config.colorName == .default)
    }

    @Test func noRecoveryWhenPreviousIsNil() {
        let config = StatusItemMapper.config(
            for: .normal, previousSeverity: nil
        )
        #expect(config.showRecoveryFlash == false)
    }

    @Test func noRecoveryWhenEscalating() {
        let config = StatusItemMapper.config(
            for: .critical, previousSeverity: .warning
        )
        #expect(config.showRecoveryFlash == false)
    }

    @Test func noRecoveryFromInfoToNormal() {
        let config = StatusItemMapper.config(
            for: .normal, previousSeverity: .info
        )
        #expect(config.showRecoveryFlash == false)
        #expect(config.colorName == .default)
    }

    // MARK: - Accessibility

    @Test func eachSeverityHasDistinctAccessibilityLabel() {
        let labels = Severity.allCases.map { severity in
            StatusItemMapper.config(for: severity).accessibilityLabel
        }
        let uniqueLabels = Set(labels)
        #expect(uniqueLabels.count == labels.count)
    }

    // MARK: - Equatable

    @Test func sameConfigIsEqual() {
        let config1 = StatusItemMapper.config(for: .warning)
        let config2 = StatusItemMapper.config(for: .warning)
        #expect(config1 == config2)
    }

    @Test func differentSeverityConfigsAreNotEqual() {
        let normal = StatusItemMapper.config(for: .normal)
        let critical = StatusItemMapper.config(for: .critical)
        #expect(normal != critical)
    }
}
