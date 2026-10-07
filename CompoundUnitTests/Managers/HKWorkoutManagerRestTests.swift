//
//  HKWorkoutManagerRestTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

#if canImport(HealthKit) && !targetEnvironment(macCatalyst)

/// The rest timer that lives on `HKWorkoutManager`.
///
/// No `HKWorkoutSession` can be started in a test process, so everything here is the half of the
/// manager that does not need one: the rest timer, the shared storage it writes for the widget, and
/// the announcement the tracker screen listens for. `state` therefore stays `.notStarted`
/// throughout, which the manager reports as active: only a paused HealthKit session reads as not.
///
/// Serialized because the three things under test — `NotificationCenter.default`, the app group's
/// `UserDefaults`, and the process-wide dispatch queues the rest timer fires on — are all shared,
/// and two of these tests running at once would read each other's posts.
extension WorkoutRestSharedStateTests {

@MainActor
struct HKWorkoutManagerRestTests {

    /// Long enough for a timer that should have been cancelled to have fired anyway, short enough
    /// that thirteen tests do not add a minute to the suite. Only spent when the expectation holds.
    private static let slack: Duration = .seconds(1)

    /// A rest that runs out almost immediately. Driving the timer rather than waiting one out is
    /// what keeps these tests off the clock; the fractional seam exists for exactly this.
    private static let briefRest: TimeInterval = 0.05

    private func makeManager() -> (HKWorkoutManager, LiveActivityUpdaterSpy) {
        // Previous runs share the app group with this one, so a rest left behind by a crashed run
        // would otherwise be read back as a rest in progress.
        SharedWorkoutStorage.clearRestEndTime()
        let spy = LiveActivityUpdaterSpy()
        return (HKWorkoutManager(logger: LogManager(), liveActivityUpdater: spy, restOverNotifier: RestOverNotifierSpy()), spy)
    }

    private var session: WorkoutSessionModel {
        WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Upper",
            dateCreated: Date(timeIntervalSince1970: 1_772_000_000),
            exercises: []
        )
    }

    /// Waits out `slack` and answers whether the rest ever announced itself. Written as a wait for
    /// the thing not to happen, so a test that expects silence spends the whole window.
    private func announced(_ spy: RestCompletionSpy) async -> Bool {
        await TestManagers.eventually(timeout: Self.slack) { spy.count > 0 }
    }

    // MARK: - Starting

    @Test("Test Starting A Rest Sets The End Time")
    func testStartingARestSetsTheEndTime() {
        let (manager, _) = makeManager()
        let before = Date()

        manager.startRest(durationSeconds: 90, session: session)

        let end = manager.restEndTime
        #expect(end != nil)
        #expect((end?.timeIntervalSince(before) ?? 0) >= 90)
        #expect((end?.timeIntervalSince(before) ?? 0) < 95)
    }

    /// The widget reads the countdown out of the app group rather than being handed it, so a rest
    /// the manager knows about and the group does not is a Dynamic Island stuck on the last value.
    @Test("Test Starting A Rest Shares The End Time With The Widget")
    func testStartingARestSharesTheEndTimeWithTheWidget() throws {
        let (manager, _) = makeManager()

        manager.startRest(durationSeconds: 90, session: session)

        let shared = try #require(SharedWorkoutStorage.restEndTime)
        let end = try #require(manager.restEndTime)
        // Shared storage keeps a `timeIntervalSince1970`, so the two are the same instant rather
        // than the same `Date` value.
        #expect(abs(shared.timeIntervalSince(end)) < 0.001)
    }

    @Test("Test Starting A Rest Puts The Countdown On The Live Activity")
    func testStartingARestPutsTheCountdownOnTheLiveActivity() throws {
        let (manager, spy) = makeManager()

        manager.startRest(durationSeconds: 90, session: session, currentExerciseIndex: 3)

        let update = try #require(spy.fullUpdates.last)
        #expect(update.restEndsAt == manager.restEndTime)
        #expect(update.restEndsAt != nil)
        #expect(update.currentExerciseIndex == 3)
    }

    /// `max(0, …)` guards this. A negative duration would otherwise put the end time in the past,
    /// which reads everywhere else as "not resting" while a timer is still scheduled.
    @Test("Test A Negative Duration Rests For No Time Rather Than Ending In The Past")
    func testANegativeDurationRestsForNoTime() {
        let (manager, _) = makeManager()
        let before = Date()

        manager.startRest(durationSeconds: -30, session: session)

        #expect((manager.restEndTime?.timeIntervalSince(before) ?? -1) >= 0)
    }

    /// `startRest(duration:)` takes a `TimeInterval` a caller could hand it directly, unlike the
    /// whole-seconds overload the app actually calls. `Int(_:)` traps on a non-finite value, and a
    /// one-sided `max(0, …)` does not filter NaN either — every comparison against NaN is false, so
    /// it passes straight through unclamped. This is the exact shape of bug fixed seven times
    /// elsewhere in this codebase via `Double.clamped(to:whenNotFinite:)`.
    @Test("Test A Non-Finite Duration Does Not Trap And Rests For A Sane Amount Of Time")
    func testANonFiniteDurationDoesNotTrapAndRestsForASaneAmountOfTime() {
        let (manager, _) = makeManager()
        let before = Date()

        manager.startRest(duration: .nan, session: session)
        let nanEnd = manager.restEndTime
        #expect(nanEnd != nil)
        #expect((nanEnd?.timeIntervalSince(before) ?? -1) >= 0)

        manager.startRest(duration: .infinity, session: session)
        let infinityEnd = manager.restEndTime
        #expect(infinityEnd != nil)
        // Clamped to a bounded ceiling rather than left as an unusable "rest forever".
        #expect((infinityEnd?.timeIntervalSince(before) ?? -1) <= 86_401)
    }

    /// The rest's start is the owner's too, so the inline timer's progress is the same wherever
    /// the rest was started, and a relaunch can take it back (system.md #3, #4).
    @Test("Test Starting A Rest Records Its Start Beside Its End")
    func testStartingARestRecordsItsStart() throws {
        let (manager, _) = makeManager()
        let before = Date()

        manager.startRest(durationSeconds: 90, session: session)

        let start = try #require(manager.restStartedAt)
        #expect(start >= before)
        #expect(try #require(SharedWorkoutStorage.appGroup.restStartedAt).timeIntervalSince(start).magnitude < 0.001)
        manager.cancelRest()
    }

    // MARK: - Running Out

    /// Kept after the rest runs out, so the row reads Ready until the next set.
    @Test("Test A Rest That Runs Out Keeps Its Start")
    func testARestThatRunsOutKeepsItsStart() async {
        let (manager, _) = makeManager()

        manager.startRest(duration: Self.briefRest, session: session)

        #expect(await TestManagers.eventually { manager.restEndTime == nil })
        #expect(manager.restStartedAt != nil)
        #expect(SharedWorkoutStorage.appGroup.restStartedAt != nil)
        manager.cancelRest()
    }

    @Test("Test A Rest That Runs Out Announces Itself")
    func testARestThatRunsOutAnnouncesItself() async {
        let (manager, _) = makeManager()
        let posts = RestCompletionSpy(manager)

        manager.startRest(duration: Self.briefRest, session: session)

        #expect(await TestManagers.eventually { posts.count == 1 })
        #expect(manager.restEndTime == nil)
    }

    /// The announcement is what fires the sound and the vibration on the tracker screen, and it is
    /// posted above the Live Activity guards in `endRest` on purpose: a rest that has run out is
    /// over whether or not there is an activity left to redraw.
    @Test("Test A Rest Announces Itself Even With No Live Activity Updater")
    func testARestAnnouncesItselfWithNoLiveActivityUpdater() async {
        SharedWorkoutStorage.clearRestEndTime()
        let manager = HKWorkoutManager(logger: LogManager(), liveActivityUpdater: nil, restOverNotifier: RestOverNotifierSpy())
        let posts = RestCompletionSpy(manager)

        manager.startRest(duration: Self.briefRest, session: session)

        #expect(await TestManagers.eventually { posts.count == 1 })
    }

    @Test("Test A Rest That Runs Out Clears The Shared Copy")
    func testARestThatRunsOutClearsTheSharedCopy() async {
        let (manager, _) = makeManager()

        manager.startRest(duration: Self.briefRest, session: session)

        #expect(await TestManagers.eventually { SharedWorkoutStorage.restEndTime == nil })
    }

    // MARK: - Cancelling

    /// The distinction the whole feature turns on: a user who cancelled a rest already knows it
    /// ended, so cancelling must not ding them.
    @Test("Test A Cancelled Rest Announces Nothing")
    func testACancelledRestAnnouncesNothing() async {
        let (manager, _) = makeManager()
        let posts = RestCompletionSpy(manager)

        manager.startRest(duration: Self.briefRest, session: session)
        manager.cancelRest()

        #expect(await announced(posts) == false)
    }

    @Test("Test Cancelling Clears The End Time And The Shared Copy")
    func testCancellingClearsTheEndTimeAndTheSharedCopy() {
        let (manager, _) = makeManager()
        manager.startRest(durationSeconds: 90, session: session)
        #expect(manager.restEndTime != nil)

        manager.cancelRest()

        #expect(manager.restEndTime == nil)
        #expect(SharedWorkoutStorage.restEndTime == nil)
        #expect(manager.restStartedAt == nil)
        #expect(SharedWorkoutStorage.appGroup.restStartedAt == nil)
    }

    /// `updateRestAndActive` rather than a full update, so the exercise the Live Activity is
    /// showing survives the cancel.
    @Test("Test Cancelling Clears The Countdown Without Redrawing The Exercise")
    func testCancellingClearsTheCountdownWithoutRedrawingTheExercise() throws {
        let (manager, spy) = makeManager()
        manager.startRest(durationSeconds: 90, session: session, currentExerciseIndex: 3)
        let updatesBefore = spy.fullUpdates.count

        manager.cancelRest()

        #expect(spy.restAndActiveUpdates.last?.restEndsAt == nil)
        #expect(spy.fullUpdates.count == updatesBefore)
    }

    // MARK: - Replacing

    /// Two live timers would announce the first rest's end in the middle of the second one.
    @Test("Test Starting A Second Rest Replaces The First Rather Than Running Both")
    func testStartingASecondRestReplacesTheFirst() async {
        let (manager, _) = makeManager()
        let posts = RestCompletionSpy(manager)

        manager.startRest(duration: Self.briefRest, session: session)
        manager.startRest(durationSeconds: 90, session: session)

        #expect(await announced(posts) == false)
        #expect((manager.restEndTime?.timeIntervalSinceNow ?? 0) > 60)
    }

    /// Replacing used to go through `cancelRest()`, whose "no rest" push and the new countdown's
    /// push were two unordered tasks: a "Rest over" frame before every countdown, and the countdown
    /// lost if they ever swapped. Only the timer is cancelled now; the activity sees one push.
    @Test("Test Replacing A Rest Pushes The New Countdown And Never A Cleared One")
    func testReplacingARestPushesTheNewCountdownAndNeverAClearedOne() throws {
        let (manager, spy) = makeManager()

        manager.startRest(durationSeconds: 60, session: session)
        manager.startRest(durationSeconds: 90, session: session)

        #expect(!spy.restAndActiveUpdates.contains { $0.restEndsAt == nil })
        #expect(try #require(spy.fullUpdates.last).restEndsAt == manager.restEndTime)
    }

    /// The split must not cost the cancel its push: one cleared countdown, no more.
    @Test("Test Cancelling A Rest Pushes Exactly One Cleared Countdown")
    func testCancellingARestPushesExactlyOneClearedCountdown() {
        let (manager, spy) = makeManager()
        manager.startRest(durationSeconds: 90, session: session)

        manager.cancelRest()

        #expect(spy.restAndActiveUpdates.filter { $0.restEndsAt == nil }.count == 1)
    }

    // MARK: - Workout Lifecycle

    @Test("Test Ending The Workout Cancels The Rest Without Announcing It")
    func testEndingTheWorkoutCancelsTheRestWithoutAnnouncingIt() async {
        let (manager, _) = makeManager()
        let posts = RestCompletionSpy(manager)
        manager.startRest(duration: Self.briefRest, session: session)

        manager.endWorkout()

        #expect(manager.restEndTime == nil)
        #expect(SharedWorkoutStorage.restEndTime == nil)
        #expect(await announced(posts) == false)
    }

    @Test("Test Discarding The Workout Cancels The Rest And Clears The Metrics")
    func testDiscardingTheWorkoutCancelsTheRestAndClearsTheMetrics() async {
        let (manager, _) = makeManager()
        let posts = RestCompletionSpy(manager)
        manager.startRest(duration: Self.briefRest, session: session)
        manager.metrics.elapsedTime = 120
        manager.metrics.heartRate = 140

        manager.discardWorkout()

        #expect(manager.restEndTime == nil)
        #expect(manager.metrics.elapsedTime == 0)
        #expect(manager.metrics.heartRate == nil)
        #expect(await announced(posts) == false)
    }

    /// A rest timer holds the manager only weakly, so a workout that is torn down mid-rest takes
    /// the manager with it rather than leaving it alive until the rest would have ended.
    @Test("Test A Manager Released Mid-Rest Is Deallocated")
    func testAManagerReleasedMidRestIsDeallocated() {
        SharedWorkoutStorage.clearRestEndTime()
        let spy = LiveActivityUpdaterSpy()
        var manager: HKWorkoutManager? = HKWorkoutManager(logger: LogManager(), liveActivityUpdater: spy, restOverNotifier: RestOverNotifierSpy())
        weak let weakManager = manager
        manager?.startRest(durationSeconds: 3600, session: session)

        manager = nil

        #expect(weakManager == nil)
    }
}

}

#endif
