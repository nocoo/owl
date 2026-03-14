import Testing
import Foundation
@testable import OwlCore

@Suite("DetectorCatalog")
struct DetectorCatalogTests {

    @Test func catalogContains20Entries() {
        #expect(DetectorCatalog.all.count == 20)
    }

    @Test func allIDsMatchesCatalogCount() {
        #expect(
            DetectorCatalog.allIDs.count
                == DetectorCatalog.all.count
        )
    }

    @Test func allIDsAreUnique() {
        let ids = DetectorCatalog.allIDs
        #expect(Set(ids).count == ids.count)
    }

    @Test func catalogMatchesPatternAndMetricsCatalogs() {
        let patternIDs = Set(
            PatternCatalog.makeAll().map(\.id)
        )
        let metricsIDs = Set(
            MetricsCatalog.makeAll().map(\.id)
        )
        let catalogIDs = Set(DetectorCatalog.allIDs)
        #expect(patternIDs.union(metricsIDs) == catalogIDs)
    }

    @Test func lookupByID() {
        let info = DetectorCatalog.info(for: "thermal_throttling")
        #expect(info != nil)
        #expect(info?.displayName == "Thermal Throttling")
    }

    @Test func lookupMissingReturnsNil() {
        let info = DetectorCatalog.info(for: "nonexistent")
        #expect(info == nil)
    }

    @Test func allEntriesHaveNonEmptyFields() {
        for entry in DetectorCatalog.all {
            #expect(!entry.id.isEmpty)
            #expect(!entry.displayName.isEmpty)
            #expect(!entry.description.isEmpty)
        }
    }

    @Test func groupedCoversAllDetectors() {
        let grouped = DetectorCatalog.grouped
        let totalCount = grouped.reduce(0) { $0 + $1.1.count }
        #expect(totalCount == DetectorCatalog.all.count)
    }

    @Test func groupedCategoriesAreUnique() {
        let categories = DetectorCatalog.grouped.map(\.0)
        #expect(Set(categories).count == categories.count)
    }

    @Test func allEntriesHaveCategory() {
        for entry in DetectorCatalog.all {
            // Verify category is a valid DetectorCategory
            #expect(
                DetectorCategory.allCases.contains(entry.category)
            )
        }
    }
}
