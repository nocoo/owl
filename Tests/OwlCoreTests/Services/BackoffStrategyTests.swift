import Foundation
import Testing
@testable import OwlCore

@Suite("BackoffStrategy")
struct BackoffStrategyTests {

    @Test func initialDelayIsBaseDelay() {
        var strategy = BackoffStrategy()
        #expect(strategy.nextDelay() == 1.0)
    }

    @Test func doublesOnEachAttempt() {
        var strategy = BackoffStrategy()
        #expect(strategy.nextDelay() == 1.0) // attempt 0
        #expect(strategy.nextDelay() == 2.0) // attempt 1
        #expect(strategy.nextDelay() == 4.0) // attempt 2
        #expect(strategy.nextDelay() == 8.0) // attempt 3
    }

    @Test func capsAtMaxDelay() {
        var strategy = BackoffStrategy(
            baseDelay: 1.0,
            maxDelay: 10.0
        )
        _ = strategy.nextDelay() // 1
        _ = strategy.nextDelay() // 2
        _ = strategy.nextDelay() // 4
        _ = strategy.nextDelay() // 8
        let fifth = strategy.nextDelay() // would be 16, capped at 10
        #expect(fifth == 10.0)
    }

    @Test func defaultMaxDelayIs30() {
        var strategy = BackoffStrategy()
        // 1, 2, 4, 8, 16, 32→30
        _ = strategy.nextDelay()
        _ = strategy.nextDelay()
        _ = strategy.nextDelay()
        _ = strategy.nextDelay()
        _ = strategy.nextDelay()
        let sixth = strategy.nextDelay()
        #expect(sixth == 30.0)
    }

    @Test func resetResetsToInitialDelay() {
        var strategy = BackoffStrategy()
        _ = strategy.nextDelay() // 1
        _ = strategy.nextDelay() // 2
        _ = strategy.nextDelay() // 4
        strategy.reset()
        #expect(strategy.nextDelay() == 1.0)
    }

    @Test func customBaseDelay() {
        var strategy = BackoffStrategy(
            baseDelay: 0.5,
            maxDelay: 30.0
        )
        #expect(strategy.nextDelay() == 0.5)
        #expect(strategy.nextDelay() == 1.0)
        #expect(strategy.nextDelay() == 2.0)
    }

    @Test func attemptCountTracksNumberOfCalls() {
        var strategy = BackoffStrategy()
        #expect(strategy.attemptCount == 0)
        _ = strategy.nextDelay()
        #expect(strategy.attemptCount == 1)
        _ = strategy.nextDelay()
        #expect(strategy.attemptCount == 2)
    }

    @Test func resetClearsAttemptCount() {
        var strategy = BackoffStrategy()
        _ = strategy.nextDelay()
        _ = strategy.nextDelay()
        strategy.reset()
        #expect(strategy.attemptCount == 0)
    }
}
