//
//  HKWorkoutManagerPauseTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

#if canImport(HealthKit) && !targetEnvironment(macCatalyst)

/// Pause and Resume. No HealthKit session can run in a test process, which is also the case on a
/// phone that declined HealthKit, so these pin that pausing works without one.
///
/// Nested under `WorkoutRestSharedStateTests`: ending and discarding clear the rest's shared copy
/// in the app group, which the rest suites read.
extension WorkoutRestSharedStateTests {

@MainActor
struct HKWorkoutManagerPauseTests {

    private func makeManager() -> (HKWorkoutManager, LiveActivityUpdaterSpy) {
        let spy = LiveActivityUpdaterSpy()
        return (HKWorkoutManager(logger: LogManager(), liveActivityUpdater: spy, restOverNotifier: RestOverNotifierSpy()), spy)
    }

    @Test("Test Pausing Shows The Live Activity's Paused Phase And Resuming Clears It")
    func testPausingAndResumingReachTheLiveActivity() {
        let (manager, spy) = makeManager()

        manager.togglePause()
        #expect(manager.isWorkoutActive == false)
        #expect(spy.restAndActiveUpdates.last?.isActive == false)

        manager.togglePause()
        #expect(manager.isWorkoutActive)
        #expect(spy.restAndActiveUpdates.last?.isActive == true)
    }

    /// The clock leaves paused time out: what has been paused so far, the current pause included.
    @Test("Test Paused Time Is Counted Up To Now")
    func testPausedTimeIsCountedUpToNow() throws {
        let (manager, _) = makeManager()

        manager.pause()
        let pausedAt = try #require(manager.pausedAt)
        #expect(manager.totalPausedDuration(at: pausedAt.addingTimeInterval(30)) == 30)

        manager.resume()
        let afterResume = manager.totalPausedDuration(at: Date().addingTimeInterval(600))
        #expect(afterResume == manager.pausedDuration)
        #expect(afterResume < 5)
    }

    /// Written where a relaunch reads it, so a paused workout comes back paused (system.md #4).
    @Test("Test Pausing And Resuming Are Kept Beyond The Process")
    func testPauseIsKeptBeyondTheProcess() throws {
        let store = SharedWorkoutStorage.Store(defaults: UserDefaults(suiteName: "HKWorkoutManagerPauseTests-\(UUID().uuidString)"))
        let manager = HKWorkoutManager(logger: LogManager(), liveActivityUpdater: LiveActivityUpdaterSpy(), restOverNotifier: RestOverNotifierSpy(), storage: store)

        manager.pause()
        #expect(store.pausedAt == manager.pausedAt)
        #expect(store.pausedAt != nil)

        manager.resume()
        #expect(store.pausedAt == nil)
        #expect(store.pausedDuration == manager.pausedDuration)
    }

    /// A finished or discarded workout's pause does not carry into the next one.
    @Test("Test Ending Or Discarding Clears The Pause", arguments: [true, false])
    func testEndingOrDiscardingClearsThePause(ends: Bool) {
        let (manager, _) = makeManager()
        manager.pause()

        if ends { manager.endWorkout() } else { manager.discardWorkout() }

        #expect(manager.isWorkoutActive)
        #expect(manager.totalPausedDuration(at: Date()) == 0)
    }
}

}

#endif
