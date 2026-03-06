import Foundation
import Testing
@testable import OwlCore

@Suite("Severity")
struct SeverityTests {

    // MARK: - Comparable ordering

    @Test func orderingIsNormalInfoWarningCritical() {
        #expect(Severity.normal < Severity.info)
        #expect(Severity.info < Severity.warning)
        #expect(Severity.warning < Severity.critical)
    }

    @Test func normalIsLowest() {
        #expect(Severity.normal < Severity.info)
        #expect(Severity.normal < Severity.warning)
        #expect(Severity.normal < Severity.critical)
    }

    @Test func criticalIsHighest() {
        #expect(Severity.critical > Severity.normal)
        #expect(Severity.critical > Severity.info)
        #expect(Severity.critical > Severity.warning)
    }

    @Test func sameSeverityIsEqual() {
        #expect(Severity.warning == Severity.warning)
    }

    // MARK: - Max aggregation

    @Test func maxOfArrayReturnsCritical() {
        let severities: [Severity] = [.normal, .warning, .info, .critical]
        #expect(severities.max() == .critical)
    }

    @Test func maxOfEmptyArrayIsNil() {
        let empty: [Severity] = []
        #expect(empty.max() == nil)
    }

    // MARK: - Codable round-trip

    @Test func codableRoundTrip() throws {
        for severity in [Severity.normal, .info, .warning, .critical] {
            let data = try JSONEncoder().encode(severity)
            let decoded = try JSONDecoder().decode(Severity.self, from: data)
            #expect(decoded == severity)
        }
    }

    // MARK: - String representation

    @Test func allCasesExist() {
        let allCases: [Severity] = [.normal, .info, .warning, .critical]
        #expect(allCases.count == 4)
    }
}
