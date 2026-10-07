//
//  WorkoutRelaunchRecoveryTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

#if canImport(HealthKit) && !targetEnvironment(macCatalyst)

/// A cold relaunch mid-workout: a fresh `HKWorkoutManager` over the store a killed process left
/// behind takes back the rest and the pause (system.md #4, edges.md "App killed mid-set").
///
/// Each test has a store of its own, so nothing here touches the App Group the other rest suites
/// share.
@MainActor
struct WorkoutRelaunchRecoveryTests {

    private let now = Date()

    private func makeStore() -> SharedWorkoutStorage.Store {
        SharedWorkoutStorage.Store(defaults: UserDefaults(suiteName: "WorkoutRelaunchRecoveryTests-\(UUID().uuidString)"))
    }

    private func makeManager(
        over store: SharedWorkoutStorage.Store,
        notifier: RestOverNotifierSpy? = nil
    ) -> (HKWorkoutManager, LiveActivityUpdaterSpy) {
        let spy = LiveActivityUpdaterSpy()
        let manager = HKWorkoutManager(logger: LogManager(), liveActivityUpdater: spy, restOverNotifier: notifier ?? RestOverNotifierSpy(), storage: store)
        return (manager, spy)
    }

    private let session = WorkoutSessionModel(
        id: "session-1",
        authorId: "author-1",
        name: "Upper",
        dateCreated: Date(timeIntervalSince1970: 1_772_000_000),
        exercises: []
    )

    // MARK: - Rest

    /// The manual check, as a test: kill mid-rest and relaunch, and the countdown matches the one
    /// the Lock Screen kept drawing.
    @Test("Test A Rest Started Before The Kill Counts Down To The Same End After It")
    func testRestSurvivesARelaunch() throws {
        let store = makeStore()
        let (before, _) = makeManager(over: store)
        before.startRest(durationSeconds: 90, session: session)
        let end = try #require(before.restEndTime)
        let start = try #require(before.restStartedAt)

        let (after, _) = makeManager(over: store)
        after.restoreAfterLaunch(activeSession: session)

        #expect(try #require(after.restEndTime).timeIntervalSince(end).magnitude < 0.001)
        #expect(try #require(after.restStartedAt).timeIntervalSince(start).magnitude < 0.001)
        after.cancelRest()
    }

    /// Re-armed, not just remembered: the rest still ends on its own.
    @Test("Test A Restored Rest Still Runs Out And Announces Itself")
    func testRestoredRestRunsOut() async {
        let store = makeStore()
        store.restEndTime = Date().addingTimeInterval(0.05)
        store.restStartedAt = now.addingTimeInterval(-60)
        let (manager, _) = makeManager(over: store)
        let posts = RestCompletionSpy(manager)

        manager.restoreAfterLaunch(activeSession: session)

        #expect(await TestManagers.eventually { posts.count == 1 })
        #expect(manager.restEndTime == nil)
        #expect(store.restEndTime == nil)
        // Kept, so the row reads Ready until the next set.
        #expect(manager.restStartedAt == store.restStartedAt)
    }

    /// The notification scheduled with the rest has already said it is over, so the Live Activity
    /// does not alert a second time and the notification is not withdrawn.
    @Test("Test A Rest That Ran Out While The App Was Gone Ends Once And Announces Nothing Twice")
    func testRestEndedWhileGone() async {
        let store = makeStore()
        store.restEndTime = now.addingTimeInterval(-600)
        store.restStartedAt = now.addingTimeInterval(-690)
        let notifier = RestOverNotifierSpy()
        let (manager, spy) = makeManager(over: store, notifier: notifier)
        spy.isShowingLiveActivity = true
        let posts = RestCompletionSpy(manager)

        manager.restoreAfterLaunch(activeSession: session, now: now)

        #expect(posts.count == 1)
        #expect(spy.restOverAnnouncements.isEmpty)
        #expect(notifier.calls.isEmpty)
        #expect(manager.restEndTime == nil)
        #expect(store.restEndTime == nil)
        // Cleared on the Live Activity, which still showed the countdown.
        #expect(spy.restAndActiveUpdates.last?.restEndsAt == nil)
    }

    // MARK: - Pause

    /// Paused for 50 s before, and again since `pausedAt`: the clock leaves out both.
    @Test("Test A Paused Workout Comes Back Paused With The Right Clock")
    func testPauseSurvivesARelaunch() {
        let store = makeStore()
        store.pausedAt = now.addingTimeInterval(-100)
        store.pausedDuration = 50
        let (manager, _) = makeManager(over: store)

        manager.restoreAfterLaunch(activeSession: session, now: now)

        #expect(manager.isWorkoutActive == false)
        #expect(manager.totalPausedDuration(at: now) == 150)
    }

    @Test("Test Pause And Resume Are Written Where A Relaunch Reads Them")
    func testPauseRoundTrip() throws {
        let store = makeStore()
        let (before, _) = makeManager(over: store)
        before.pause()
        let pausedAt = try #require(before.pausedAt)

        let (after, _) = makeManager(over: store)
        after.restoreAfterLaunch(activeSession: session)
        #expect(after.pausedAt == pausedAt)

        after.resume()
        #expect(store.pausedAt == nil)
        #expect(store.pausedDuration == after.pausedDuration)
        #expect(after.pausedDuration > 0)
    }

    // MARK: - Nothing to resume

    @Test("Test With No Workout To Resume What Was Left Behind Is Cleared")
    func testNoWorkoutClearsStaleState() {
        let store = makeStore()
        store.restEndTime = now.addingTimeInterval(60)
        store.restStartedAt = now
        store.pausedAt = now
        store.pausedDuration = 30
        let (manager, _) = makeManager(over: store)

        manager.restoreAfterLaunch(activeSession: nil, now: now)

        #expect(manager.restEndTime == nil)
        #expect(manager.isWorkoutActive)
        #expect(store.restEndTime == nil)
        #expect(store.restStartedAt == nil)
        #expect(store.pausedAt == nil)
        #expect(store.pausedDuration == 0)
    }

    /// Apple Health is picked up only for the workout a session was started for, so another
    /// workout never gets one it did not ask for.
    @Test("Test Apple Health Is Not Restarted For A Workout It Was Never Started For")
    func testHealthKitLeftAloneForAnotherWorkout() async {
        let store = makeStore()
        store.hkStartedSessionId = "another-session"
        let (manager, _) = makeManager(over: store)

        await manager.recoverHealthKitSession(for: session)

        #expect(manager.session == nil)
    }
}

#endif
