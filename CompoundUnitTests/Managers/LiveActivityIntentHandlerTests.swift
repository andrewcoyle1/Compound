//
//  LiveActivityIntentHandlerTests.swift
//  CompoundUnitTests
//
//  The in-process handler the Live Activity's buttons reach the app through
//  (docs/specs/live-activity.md §7.4).
//

import Testing
import Foundation
@testable import Compound

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)

/// What the widget's buttons actually do, now that they do it here rather than leaving a note in
/// the app group for a one-second poll to find.
///
/// Built on real managers through `TestManagers`, because the bug this replaces was not in any
/// decision — it was in the wiring between the managers, and a double for the session manager would
/// have passed the whole time.
///
/// Serialized: `HKWorkoutManager`'s rest timer writes the app group's shared storage and fires on
/// process-wide dispatch queues, so two of these running at once read each other's rests.
@MainActor
private struct Rig {
    let handler: AppLiveActivityIntentHandler
    let sessions: WorkoutSessionManager
    let hkWorkoutManager: HKWorkoutManager
    let activity: LiveActivityUpdaterSpy
    let users: UserManager
    let screenStateStore: UserDefaults
}

extension WorkoutRestSharedStateTests {

@MainActor
struct LiveActivityIntentHandlerTests {

    private static let start = Date(timeIntervalSince1970: 1_772_000_000)

    // MARK: - Fixtures

    private func set(_ id: String, index: Int, reps: Int = 8, weightKg: Double = 60, done: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id,
            authorId: "author-1",
            index: index,
            reps: reps,
            weightKg: weightKg,
            isWarmup: false,
            completedAt: done ? Self.start : nil,
            dateCreated: Self.start
        )
    }

    private func exercise(id: String = "e1", index: Int = 1, sets: [WorkoutSetModel], group: String? = nil) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: id,
            authorId: "author-1",
            templateId: "template-\(index)",
            name: "Exercise \(index)",
            trackingMode: .weightReps,
            index: index,
            sets: sets,
            supersetGroupId: group
        )
    }

    private func session(exercises: [WorkoutExerciseModel], mesocycle: Mesocycle? = nil) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Push Day",
            workoutTemplateId: mesocycle?.workoutTemplates.first?.id,
            mesocycleId: mesocycle?.id,
            dateCreated: Self.start,
            exercises: exercises
        )
    }

    private func makeRig(
        sets: [WorkoutSetModel],
        settings: (inout WorkoutSettings) -> Void = { _ in }
    ) async throws -> Rig {
        try await makeRig(exercises: [exercise(sets: sets)], settings: settings)
    }

    /// `mesocycle`, when given, is the user's active mesocycle and the session is its first workout;
    /// the session and mesocycle managers are then signed in so what finishing writes can be read.
    private func makeRig(
        exercises: [WorkoutExerciseModel],
        mesocycle: Mesocycle? = nil,
        weeklyGoal: Int? = nil,
        settings: (inout WorkoutSettings) -> Void = { _ in }
    ) async throws -> Rig {
        // A rest left behind by an earlier run would otherwise read back as one in progress.
        SharedWorkoutStorage.clearRestEndTime()

        var workoutSettings = WorkoutSettings(authorId: "author-1")
        workoutSettings.defaultRestDurationSeconds = 75
        settings(&workoutSettings)

        let sessions = mesocycle == nil && weeklyGoal == nil
            ? TestManagers.workoutSessionManager()
            : await TestManagers.signedInWorkoutSessionManager(sessions: [])
        try sessions.updateActiveSession(session(exercises: exercises, mesocycle: mesocycle))
        let mesocycles = await TestManagers.signedInMesocycleManager(mesocycles: [mesocycle].compactMap { $0 })
        let users = try await TestManagers.signedInUserManager(
            UserModel(userId: "author-1", submittedActiveMesocycleId: mesocycle?.id, weeklySessionGoal: weeklyGoal)
        )

        let settingsManager = try await TestManagers.signedInWorkoutSettingsManager(workoutSettings)
        let activity = LiveActivityUpdaterSpy()
        let hkWorkoutManager = HKWorkoutManager(logger: LogManager(), liveActivityUpdater: activity, restOverNotifier: RestOverNotifierSpy())
        let screenStateStore = UserDefaults(suiteName: "LiveActivityIntentHandlerTests-\(UUID().uuidString)") ?? .standard

        let handler = AppLiveActivityIntentHandler(
            workoutSessionManager: sessions,
            hkWorkoutManager: hkWorkoutManager,
            liveActivityUpdater: activity,
            workoutSettingsManager: settingsManager,
            exerciseSettingsManager: TestManagers.exerciseSettingsManager(),
            exerciseModelManager: TestManagers.exerciseModelManager(),
            gymProfileManager: TestManagers.gymProfileManager(),
            mesocycleManager: mesocycles,
            userManager: users,
            screenStateStore: screenStateStore
        )

        return Rig(
            handler: handler,
            sessions: sessions,
            hkWorkoutManager: hkWorkoutManager,
            activity: activity,
            users: users,
            screenStateStore: screenStateStore
        )
    }

    /// The sets of the one exercise on the active session.
    private func savedSets(_ rig: Rig) throws -> [WorkoutSetModel] {
        try #require(rig.sessions.activeSession?.exercises.first?.sets)
    }

    // MARK: - Completing a set

    /// The whole bug this replaces: the widget advanced its set number and the app logged nothing.
    /// The set is logged with its own numbers — the widget's `target*` fields are a formatted copy
    /// and never touch the session.
    @Test("Test Completing A Set Logs That Set With Its Own Targets")
    func testCompletingASetLogsThatSetWithItsOwnTargets() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1), set("s2", index: 2)])

        await rig.handler.completeSet(id: "s1")

        let sets = try savedSets(rig)
        #expect(sets[0].completedAt != nil)
        #expect(sets[0].reps == 8)
        #expect(sets[0].weightKg == 60)
        // Only the set named is logged.
        #expect(sets[1].completedAt == nil)
    }

    /// The rest that follows is the one the set-row presenter would have started: the user's own
    /// setting, through `RestDurationRules`, not a fixed ninety seconds invented by the widget.
    @Test("Test Completing A Set Starts The Settings Derived Rest")
    func testCompletingASetStartsTheSettingsDerivedRest() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1), set("s2", index: 2)])

        await rig.handler.completeSet(id: "s1")

        let restEndTime = try #require(rig.hkWorkoutManager.restEndTime)
        let seconds = restEndTime.timeIntervalSinceNow
        #expect(seconds > 70 && seconds <= 75)

        rig.hkWorkoutManager.cancelRest()
    }

    /// Rest timers off means no rest, from the widget exactly as from the tracker.
    @Test("Test No Rest Is Started With Rest Timers Off")
    func testNoRestIsStartedWithRestTimersOff() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1), set("s2", index: 2)]) { $0.useRestTimers = false }

        await rig.handler.completeSet(id: "s1")

        #expect(rig.hkWorkoutManager.restEndTime == nil)
        let logged = try savedSets(rig)[0]
        #expect(logged.completedAt != nil)
    }

    /// The push is what puts the correction window on screen: the saved session is handed to the
    /// activity, and `LiveActivityManager` derives `lastLogged*` from it.
    @Test("Test Completing A Set Pushes The Saved Session")
    func testCompletingASetPushesTheSavedSession() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1), set("s2", index: 2)])

        await rig.handler.completeSet(id: "s1")

        let pushed = try #require(rig.activity.fullUpdates.last)
        #expect(pushed.session.id == "session-1")
        #expect(pushed.restEndsAt != nil)
        #expect(pushed.session.exercises[0].sets[0].completedAt != nil)

        rig.hkWorkoutManager.cancelRest()
    }

    /// A set that is already logged, or one this session does not have, is dropped rather than
    /// logged twice or against the wrong workout.
    @Test("Test An Unknown Or Already Logged Set Is Dropped")
    func testAnUnknownOrAlreadyLoggedSetIsDropped() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1, done: true)])

        await rig.handler.completeSet(id: "not-in-this-workout")
        await rig.handler.completeSet(id: "s1")

        #expect(rig.hkWorkoutManager.restEndTime == nil)
        let untouched = try savedSets(rig)[0]
        #expect(untouched.completedAt == Self.start)
    }

    /// The intent disables the button before calling in, and only a push from here re-enables it.
    /// A tap that changes nothing — a set already logged, an id this workout does not have — must
    /// still answer with a push, or the button stays dead until the tracker's next tick.
    @Test("Test A Dropped Tap Still Pushes So The Button Is Re-Enabled")
    func testADroppedTapStillPushesSoTheButtonIsReEnabled() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1, done: true)])

        await rig.handler.completeSet(id: "s1")
        #expect(rig.activity.fullUpdates.count == 1)

        await rig.handler.completeSet(id: "not-in-this-workout")
        #expect(rig.activity.fullUpdates.count == 2)

        await rig.handler.adjustLastSetReps(id: "s1", delta: -1)
        #expect(rig.activity.fullUpdates.count == 3)

        await rig.handler.adjustRest(by: 15)
        #expect(rig.activity.fullUpdates.count == 4)

        let pushed = try #require(rig.activity.fullUpdates.last)
        #expect(pushed.session.exercises[0].sets[0].completedAt == Self.start)
        #expect(pushed.restEndsAt == nil)
    }

    // MARK: - Correcting the reps

    @Test("Test A Correction During The Rest Changes Only The Reps")
    func testACorrectionDuringTheRestChangesOnlyTheReps() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1), set("s2", index: 2)])
        await rig.handler.completeSet(id: "s1")

        await rig.handler.adjustLastSetReps(id: "s1", delta: -1)

        let logged = try savedSets(rig)[0]
        #expect(logged.reps == 7)
        #expect(logged.weightKg == 60)
        #expect(logged.completedAt != nil)

        rig.hkWorkoutManager.cancelRest()
    }

    @Test("Test The Correction Is Clamped To Zero And Ninety Nine")
    func testTheCorrectionIsClampedToZeroAndNinetyNine() async throws {
        // One rep, as a set with none is not logged at all.
        let rig = try await makeRig(sets: [set("s1", index: 1, reps: 1), set("s2", index: 2)])
        await rig.handler.completeSet(id: "s1")

        await rig.handler.adjustLastSetReps(id: "s1", delta: -1)
        await rig.handler.adjustLastSetReps(id: "s1", delta: -1)
        let floored = try savedSets(rig)[0]
        #expect(floored.reps == 0)

        for _ in 0..<100 {
            await rig.handler.adjustLastSetReps(id: "s1", delta: 1)
        }
        let capped = try savedSets(rig)[0]
        #expect(capped.reps == 99)

        rig.hkWorkoutManager.cancelRest()
    }

    /// The window is the rest and nothing else. With no rest running there is no set to correct,
    /// and a stray tap must not rewrite the last one.
    @Test("Test A Correction Outside The Rest Is A No Op")
    func testACorrectionOutsideTheRestIsANoOp() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1, done: true)])

        await rig.handler.adjustLastSetReps(id: "s1", delta: -1)

        let untouched = try savedSets(rig)[0]
        #expect(untouched.reps == 8)
    }

    @Test("Test A Correction For An Unknown Set Is A No Op")
    func testACorrectionForAnUnknownSetIsANoOp() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1), set("s2", index: 2)])
        await rig.handler.completeSet(id: "s1")

        await rig.handler.adjustLastSetReps(id: "not-in-this-workout", delta: -1)

        let untouched = try savedSets(rig)[0]
        #expect(untouched.reps == 8)

        rig.hkWorkoutManager.cancelRest()
    }

    /// The rest outlives the process that started it. iOS can drop the app between two taps on
    /// the Lock Screen, and the next intent launches a fresh `HKWorkoutManager` whose own
    /// `restEndTime` is nil; the rest is still on in the app group, and the correction must
    /// still land.
    @Test("Test A Correction After A Cold Launch Still Finds The Rest")
    func testACorrectionAfterAColdLaunchStillFindsTheRest() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1, done: true), set("s2", index: 2)])
        SharedWorkoutStorage.restEndTime = Date().addingTimeInterval(60)
        defer { SharedWorkoutStorage.clearRestEndTime() }
        #expect(rig.hkWorkoutManager.restEndTime == nil)

        await rig.handler.adjustLastSetReps(id: "s1", delta: -1)

        let corrected = try savedSets(rig)[0]
        #expect(corrected.reps == 7)
    }

    // MARK: - The rest buttons

    /// Same cold launch as above, for "+15s": the rest from before the launch is the one extended,
    /// and the fresh manager takes it over from there.
    @Test("Test Adjusting The Rest After A Cold Launch Extends The Stored One")
    func testAdjustingTheRestAfterAColdLaunchExtendsTheStoredOne() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1, done: true), set("s2", index: 2)])
        let storedEnd = Date().addingTimeInterval(60)
        SharedWorkoutStorage.restEndTime = storedEnd
        #expect(rig.hkWorkoutManager.restEndTime == nil)

        await rig.handler.adjustRest(by: 15)

        let after = try #require(rig.hkWorkoutManager.restEndTime)
        #expect(after.timeIntervalSince(storedEnd) > 13)
        #expect(after.timeIntervalSince(storedEnd) < 17)

        rig.hkWorkoutManager.cancelRest()
    }

    @Test("Test Adjusting The Rest Moves Its End Time")
    func testAdjustingTheRestMovesItsEndTime() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1), set("s2", index: 2)])
        await rig.handler.completeSet(id: "s1")
        let before = try #require(rig.hkWorkoutManager.restEndTime)

        await rig.handler.adjustRest(by: 15)

        let after = try #require(rig.hkWorkoutManager.restEndTime)
        #expect(after.timeIntervalSince(before) > 13)
        #expect(after.timeIntervalSince(before) < 17)

        rig.hkWorkoutManager.cancelRest()
    }

    @Test("Test Skipping The Rest Ends It")
    func testSkippingTheRestEndsIt() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1), set("s2", index: 2)])
        await rig.handler.completeSet(id: "s1")
        #expect(rig.hkWorkoutManager.restEndTime != nil)

        await rig.handler.skipRest()

        #expect(rig.hkWorkoutManager.restEndTime == nil)
        #expect(SharedWorkoutStorage.restEndTime == nil)
    }

    // MARK: - Finishing

    /// Finish from the activity ends the session the way Finish in the app does: the workout is
    /// ended, the active session is cleared, and the activity is told the workout is over.
    @Test("Test Completing The Workout Ends The Session")
    func testCompletingTheWorkoutEndsTheSession() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1, done: true)])

        await rig.handler.completeWorkout()

        #expect(rig.sessions.activeSession == nil)
        #expect(rig.activity.ended.contains("session-1"))
    }

    /// The finish here is the tracker's finish, side effects included. The rest days that follow
    /// the workout in its mesocycle are pre-completed, which the handler's own copy of the finish
    /// used to skip.
    @Test("Test Completing The Workout Pre-Completes The Rest Days That Follow It")
    func testCompletingTheWorkoutPreCompletesTheRestDaysThatFollowIt() async throws {
        let mesocycle = Mesocycle(
            id: "program-1",
            authorId: "author-1",
            name: "Push Pull",
            icon: "dumbbell",
            colour: "red",
            workoutTemplates: [
                WorkoutTemplateModel(id: "template-push", authorId: "author-1", name: "Push"),
                WorkoutTemplateModel(id: "template-rest-1", authorId: "author-1", name: "Rest"),
                WorkoutTemplateModel(id: "template-rest-2", authorId: "author-1", name: "Rest")
            ]
        )
        let rig = try await makeRig(exercises: [exercise(sets: [set("s1", index: 1, done: true)])], mesocycle: mesocycle)

        await rig.handler.completeWorkout()

        #expect(await TestManagers.eventually { rig.sessions.workoutSessions.filter(\.isRestDay).count == 2 })
        #expect(rig.sessions.activeSession == nil)
        #expect(Set(rig.sessions.workoutSessions.filter(\.isRestDay).map(\.workoutTemplateId)) == ["template-rest-1", "template-rest-2"])
    }

    /// Followers read the streak off the session, and the evening reminder off the private settings,
    /// so finishing writes both. The session is from February 2026, long before "now", so no week is
    /// current: the streak is 0, but it is stamped.
    @Test("Test Completing The Workout Stamps The Weekly Streak")
    func testCompletingTheWorkoutStampsTheWeeklyStreak() async throws {
        let rig = try await makeRig(exercises: [exercise(sets: [set("s1", index: 1, done: true)])], weeklyGoal: 2)

        await rig.handler.completeWorkout()

        #expect(await TestManagers.eventually { rig.sessions.workoutSessions.first?.weekStreakCount == 0 })
        #expect(await TestManagers.eventually { rig.users.privateSettings.weekGoal == 2 })
        #expect(rig.users.privateSettings.weekStreak == 0)
        #expect(rig.users.privateSettings.lastTrainedAt == Self.start)
    }

    /// Nothing to finish is not an error; the handler simply has no session to end.
    @Test("Test Completing The Workout Without A Session Does Nothing")
    func testCompletingTheWorkoutWithoutASessionDoesNothing() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1)])
        try rig.sessions.deleteActiveSession()

        await rig.handler.completeWorkout()

        #expect(rig.activity.ended.isEmpty)
    }

    // MARK: - Advancing past a finished exercise

    /// Completing the last set of an exercise moves the activity on to the next exercise, so the
    /// rest shows what is coming and the banner has a live target when it ends. Pointing at the
    /// finished exercise left the widget with no target and no way forward.
    @Test("Test Completing The Last Set Advances The Activity To The Next Exercise")
    func testCompletingTheLastSetAdvancesTheActivityToTheNextExercise() async throws {
        let rig = try await makeRig(exercises: [
            exercise(id: "e1", index: 1, sets: [set("set-1", index: 1)]),
            exercise(id: "e2", index: 2, sets: [set("set-2", index: 1)])
        ])

        await rig.handler.completeSet(id: "set-1")

        let pushed = try #require(rig.activity.fullUpdates.last)
        #expect(pushed.currentExerciseIndex == 1)
    }

    // MARK: - One log rule with the tracker (WP-K)

    private func superset(transitionRest: Int? = nil) async throws -> Rig {
        try await makeRig(exercises: [
            exercise(id: "a", index: 1, sets: [set("a1", index: 1), set("a2", index: 2)], group: "g"),
            exercise(id: "b", index: 2, sets: [set("b1", index: 1), set("b2", index: 2)], group: "g")
        ]) { $0.supersetTransitionRestSeconds = transitionRest }
    }

    private func storedFocus(_ rig: Rig) -> String? {
        ActiveWorkoutScreenState.load(sessionId: "session-1", from: rig.screenStateStore).focusExerciseId
    }

    /// Worked in rounds from the Lock Screen too: A1 hands on to B, as the tracker's log does,
    /// and the exercise is kept for the tracker to open on.
    @Test("Test A1 From The Lock Screen Moves Focus To B")
    func testA1MovesFocusToB() async throws {
        let rig = try await superset()

        await rig.handler.completeSet(id: "a1")

        let pushed = try #require(rig.activity.fullUpdates.last)
        #expect(pushed.currentExerciseIndex == 1)
        #expect(storedFocus(rig) == "b")
        // The walk to the partner rests not at all by default.
        #expect(rig.hkWorkoutManager.restEndTime == nil)
    }

    @Test("Test No Rest After The Workout's Final Set")
    func testNoRestAfterTheFinalSet() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1, done: true), set("s2", index: 2)])

        await rig.handler.completeSet(id: "s2")

        #expect(try savedSets(rig)[1].completedAt != nil)
        #expect(rig.hkWorkoutManager.restEndTime == nil)
    }

    /// A set with no reps is refused, as the tracker refuses it, and the session is left as it was;
    /// the push still comes, to re-enable the button.
    @Test("Test An Invalid Set Is Refused And The State Unchanged")
    func testAnInvalidSetIsRefused() async throws {
        var empty = set("s1", index: 1)
        empty.reps = nil
        let rig = try await makeRig(sets: [empty, set("s2", index: 2)])
        let before = rig.sessions.activeSession

        await rig.handler.completeSet(id: "s1")

        #expect(rig.sessions.activeSession == before)
        #expect(rig.hkWorkoutManager.restEndTime == nil)
        #expect(rig.activity.fullUpdates.count == 1)
        #expect(storedFocus(rig) == nil)
    }

    /// "+15s", the reps correction and Skip keep the activity on the exercise the user is on, not
    /// the first with work left.
    @Test("Test The Rest Buttons Keep The Exercise")
    func testTheRestButtonsKeepTheExercise() async throws {
        let rig = try await superset(transitionRest: 30)
        await rig.handler.completeSet(id: "a1")
        #expect(rig.hkWorkoutManager.restEndTime != nil)

        await rig.handler.adjustRest(by: 15)
        #expect(rig.activity.fullUpdates.last?.currentExerciseIndex == 1)

        await rig.handler.adjustLastSetReps(id: "a1", delta: -1)
        #expect(rig.activity.fullUpdates.last?.currentExerciseIndex == 1)

        await rig.handler.skipRest()
        #expect(rig.activity.fullUpdates.last?.currentExerciseIndex == 1)
    }

    /// A rest set by hand on the row in the tracker is the rest the Lock Screen starts.
    @Test("Test The Row's Own Rest Is Used")
    func testTheRowsOwnRestIsUsed() async throws {
        let rig = try await makeRig(sets: [set("s1", index: 1), set("s2", index: 2)])
        ActiveWorkoutScreenState(sessionId: "session-1", customRestSeconds: ["s1": 30]).save(to: rig.screenStateStore)

        await rig.handler.completeSet(id: "s1")

        let seconds = try #require(rig.hkWorkoutManager.restEndTime).timeIntervalSinceNow
        #expect(seconds > 25 && seconds <= 30)
        rig.hkWorkoutManager.cancelRest()
    }
}

}

#endif
