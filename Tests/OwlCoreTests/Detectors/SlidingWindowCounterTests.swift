import Foundation
import Testing
@testable import OwlCore

@Suite("SlidingWindowCounter")
struct SlidingWindowCounterTests {

    // MARK: - Initialization

    @Test func initializesWithCorrectBucketCount() {
        let counter = SlidingWindowCounter(windowSeconds: 60, bucketDuration: 1)
        #expect(counter.total == 0)
        #expect(counter.bucketCount == 60)
    }

    @Test func initializesWithLargerBuckets() {
        let counter = SlidingWindowCounter(windowSeconds: 3600, bucketDuration: 10)
        #expect(counter.bucketCount == 360)
        #expect(counter.total == 0)
    }

    // MARK: - Increment

    @Test func incrementIncreasesTotal() {
        var counter = SlidingWindowCounter(windowSeconds: 60, bucketDuration: 1)
        let now = Date()
        counter.increment(at: now)
        #expect(counter.total == 1)
    }

    @Test func multipleIncrementsInSameSecond() {
        var counter = SlidingWindowCounter(windowSeconds: 60, bucketDuration: 1)
        let now = Date()
        counter.increment(at: now)
        counter.increment(at: now)
        counter.increment(at: now)
        #expect(counter.total == 3)
    }

    // MARK: - Advance (time progression)

    @Test func advanceToNextSecondPreservesTotal() {
        var counter = SlidingWindowCounter(windowSeconds: 60, bucketDuration: 1)
        let t0 = Date()
        counter.increment(at: t0)
        counter.increment(at: t0)

        let t1 = t0.addingTimeInterval(1)
        counter.increment(at: t1)

        #expect(counter.total == 3)
    }

    @Test func advancePastWindowClearsOldBuckets() {
        var counter = SlidingWindowCounter(windowSeconds: 10, bucketDuration: 1)
        let t0 = Date()
        counter.increment(at: t0)
        counter.increment(at: t0)
        #expect(counter.total == 2)

        // Advance past the entire window
        let t1 = t0.addingTimeInterval(11)
        counter.increment(at: t1)
        #expect(counter.total == 1) // Old events expired, only the new one
    }

    @Test func advanceWayPastWindowResetsEverything() {
        var counter = SlidingWindowCounter(windowSeconds: 60, bucketDuration: 1)
        let t0 = Date()
        counter.increment(at: t0)
        counter.increment(at: t0)
        counter.increment(at: t0)
        #expect(counter.total == 3)

        // Way past the window
        let t1 = t0.addingTimeInterval(1000)
        counter.advance(to: t1)
        #expect(counter.total == 0)
    }

    @Test func advanceByExactWindowSize() {
        var counter = SlidingWindowCounter(windowSeconds: 10, bucketDuration: 1)
        let t0 = Date()
        counter.increment(at: t0)
        #expect(counter.total == 1)

        // Advance by exactly the window size
        let t1 = t0.addingTimeInterval(10)
        counter.advance(to: t1)
        #expect(counter.total == 0) // Should be expired
    }

    // MARK: - Partial expiry

    @Test func partialExpiryRemovesOnlyOldBuckets() {
        var counter = SlidingWindowCounter(windowSeconds: 10, bucketDuration: 1)
        let t0 = Date()

        // Add events at t0
        counter.increment(at: t0)
        counter.increment(at: t0)

        // Add events at t0+5
        let t5 = t0.addingTimeInterval(5)
        counter.increment(at: t5)
        counter.increment(at: t5)
        counter.increment(at: t5)
        #expect(counter.total == 5)

        // Advance to t0+11 — t0 events expire, t5 events remain
        let t11 = t0.addingTimeInterval(11)
        counter.advance(to: t11)
        #expect(counter.total == 3) // Only t5 events remain
    }

    // MARK: - Ring buffer wrap-around

    @Test func ringBufferWrapsCorrectly() {
        var counter = SlidingWindowCounter(windowSeconds: 5, bucketDuration: 1)
        let t0 = Date()

        // Fill multiple cycles to force wrap-around
        for i in 0..<12 {
            let time = t0.addingTimeInterval(Double(i))
            counter.increment(at: time)
        }

        // At t0+11, window covers t0+7 through t0+11 = 5 events
        #expect(counter.total == 5)
    }

    // MARK: - Same timestamp no-op

    @Test func advanceToSameTimestampIsNoOp() {
        var counter = SlidingWindowCounter(windowSeconds: 60, bucketDuration: 1)
        let t0 = Date()
        counter.increment(at: t0)
        counter.increment(at: t0)

        // Advance to the same time — should be no-op
        counter.advance(to: t0)
        #expect(counter.total == 2)
    }

    // MARK: - Backward time (should be safe)

    @Test func backwardTimeIsNoOp() {
        var counter = SlidingWindowCounter(windowSeconds: 60, bucketDuration: 1)
        let t0 = Date()
        counter.increment(at: t0)

        let earlier = t0.addingTimeInterval(-5)
        counter.advance(to: earlier)
        #expect(counter.total == 1) // Should not lose data
    }

    // MARK: - Zero total after full expiry

    @Test func totalIsZeroAfterAllEventsExpire() {
        var counter = SlidingWindowCounter(windowSeconds: 5, bucketDuration: 1)
        let t0 = Date()
        counter.increment(at: t0)

        let t10 = t0.addingTimeInterval(10)
        counter.advance(to: t10)
        #expect(counter.total == 0)
    }

    // MARK: - Edge: window=1 bucket

    @Test func singleBucketWindow() {
        var counter = SlidingWindowCounter(windowSeconds: 1, bucketDuration: 1)
        let t0 = Date()
        counter.increment(at: t0)
        counter.increment(at: t0)
        #expect(counter.total == 2)

        let t1 = t0.addingTimeInterval(1)
        counter.advance(to: t1)
        #expect(counter.total == 0) // Expired
    }

    // MARK: - Stress: many increments

    @Test func highVolumeIncrements() {
        var counter = SlidingWindowCounter(windowSeconds: 60, bucketDuration: 1)
        let t0 = Date()

        for _ in 0..<1000 {
            counter.increment(at: t0)
        }
        #expect(counter.total == 1000)
    }
}
