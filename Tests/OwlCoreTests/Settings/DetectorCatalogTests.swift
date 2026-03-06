import Testing
import Foundation
@testable import OwlCore

@Suite("DetectorCatalog")
struct DetectorCatalogTests {

    @Test func catalogContains15Entries() {
        #expect(DetectorCatalog.all.count == 15)
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

    @Test func catalogMatchesPatternCatalog() {
        let patternIDs = Set(
            PatternCatalog.makeAll().map(\.id)
        )
        let catalogIDs = Set(DetectorCatalog.allIDs)
        #expect(patternIDs == catalogIDs)
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
}
