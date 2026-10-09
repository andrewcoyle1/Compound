//
//  StopwatchRuleTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The timed-hold stopwatch on a `timeOnly` row: it counts up from a tap, counts down to a target
/// when there is one, and stopping answers the seconds to write into the set.
struct StopwatchRuleTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    @Test func startStopAnswersTheSecondsHeld() {
        var stopwatch = ActiveWorkout.Stopwatch()
        #expect(!stopwatch.isRunning)
        stopwatch.start(at: start)
        #expect(stopwatch.isRunning)
        #expect(stopwatch.elapsed(at: at(42.4)) == 42)
        #expect(stopwatch.stop(at: at(42.6)) == 43)
        #expect(!stopwatch.isRunning)
        #expect(stopwatch.elapsed(at: at(60)) == 0)
    }

    @Test func aSecondStartKeepsTheFirst() {
        var stopwatch = ActiveWorkout.Stopwatch()
        stopwatch.start(at: start)
        stopwatch.start(at: at(10))
        #expect(stopwatch.startedAt == start)
    }

    /// A stop with nothing running, or a double tap, writes nothing into the set.
    @Test func aStopWithNothingHeldAnswersNothing() {
        var stopwatch = ActiveWorkout.Stopwatch()
        #expect(stopwatch.stop(at: start) == nil)
        stopwatch.start(at: start)
        #expect(stopwatch.stop(at: at(0.3)) == nil)
    }

    @Test func aTargetCountsDownAndStopsAtZero() {
        var stopwatch = ActiveWorkout.Stopwatch(targetSeconds: 45)
        #expect(stopwatch.remaining(at: start) == nil)
        #expect(stopwatch.targetInterval == nil)

        stopwatch.start(at: start)
        #expect(stopwatch.remaining(at: at(30)) == 15)
        #expect(stopwatch.remaining(at: at(50)) == 0)
        #expect(stopwatch.targetInterval == start...at(45))
    }

    @Test func noTargetMeansNoCountdown() {
        var stopwatch = ActiveWorkout.Stopwatch()
        stopwatch.start(at: start)
        #expect(stopwatch.remaining(at: at(30)) == nil)
        #expect(stopwatch.targetInterval == nil)
    }
}
