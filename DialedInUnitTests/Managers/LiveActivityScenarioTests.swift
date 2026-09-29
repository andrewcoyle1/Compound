//
//  LiveActivityScenarioTests.swift
//  DialedInUnitTests
//
//  A whole workout driven the way a user drives it from the Lock Screen: tap what the activity
//  shows, and after every tap check what the activity would show next. The widget is a pure
//  function of the content state (`LiveActivityPhase`), so asserting the phase after each push is
//  asserting what the user sees, without SpringBoard in the loop.
//
//  The two bugs this exists for were both in this loop: a completion the app never consumed, and a
//  push that pointed at a finished exercise and left the banner with no target and no way out.
//

import Foundation
import Testing
@testable import DialedIn

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

@MainActor
private struct Rig {
    let handler: AppLiveActivityIntentHandler
    let sessions: WorkoutSessionManager
    let hkWorkoutManager: HKWorkoutManager
    let activity: LiveActivityManager
    let log: SpyLogService
    let system: SystemActivity
}

/// Stands in for `Activity.activities` as the manager's lookup. The manager starts with no
/// activity, the way a process launched by a Lock Screen tap does, and must ask the system for
/// this session's on the first push; the answer is a real activity requested here, since the
/// test host is the app and can hold one.
@MainActor
private final class SystemActivity {
    var initialState: WorkoutActivityAttributes.ContentState?
    private(set) var activity: Activity<WorkoutActivityAttributes>?
    private(set) var askedFor: [String] = []

    func lookup(sessionId: String) -> Activity<WorkoutActivityAttributes>? {
        askedFor.append(sessionId)
        if activity == nil, let initialState {
            activity = try? Activity.request(
                attributes: WorkoutActivityAttributes(sessionId: sessionId, workoutName: "Full Body"),
                content: ActivityContent(state: initialState, staleDate: nil),
                pushType: nil
            )
        }
        return activity
    }

    func dismiss() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
    }
}

extension WorkoutRestSharedStateTests {

@MainActor
struct LiveActivityScenarioTests {

    private static let start = Date(timeIntervalSince1970: 1_772_000_000)

    // MARK: - Fixture: four exercises, two warm-ups and four working sets each

    private func set(exercise: Int, index: Int, warmup: Bool, side: SetSide? = nil) -> WorkoutSetModel {
        let suffix = side.map { "-\($0.rawValue)" } ?? ""
        return WorkoutSetModel(
            id: "e\(exercise)-s\(index)\(suffix)",
            authorId: "author-1",
            index: index,
            reps: warmup ? 10 : 8,
            weightKg: warmup ? 40 : 60 + Double(exercise) * 5,
            rpe: nil,
            side: side,
            isWarmup: warmup,
            completedAt: nil,
            dateCreated: Self.start
        )
    }

    /// Two warm-ups and four working sets. A unilateral exercise logs each working set as a left
    /// row and a right row, stored next to each other, left first, the way the tracker does.
    private func exercise(_ number: Int, unilateral: Bool = false) -> WorkoutExerciseModel {
        let warmups = (1...2).map { set(exercise: number, index: $0, warmup: true) }
        let working: [WorkoutSetModel] = (3...6).flatMap { index -> [WorkoutSetModel] in
            unilateral
                ? [set(exercise: number, index: index, warmup: false, side: .left),
                   set(exercise: number, index: index, warmup: false, side: .right)]
                : [set(exercise: number, index: index, warmup: false)]
        }
        return WorkoutExerciseModel(
            id: "e\(number)",
            authorId: "author-1",
            templateId: "template-\(number)",
            name: "Exercise \(number)",
            trackingMode: .weightReps,
            index: number,
            sets: warmups + working
        )
    }

    /// Four exercises; the second is unilateral, so the rows to tap number 6 + 10 + 6 + 6 = 28
    /// while the sets the user did number 24.
    private func session(
        exercises: [WorkoutExerciseModel]? = nil
    ) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: "scenario-session",
            authorId: "author-1",
            name: "Full Body",
            dateCreated: Self.start,
            exercises: exercises ?? [exercise(1), exercise(2, unilateral: true), exercise(3), exercise(4)]
        )
    }

    private static let rowsToTap = 28
    private static let setsDone = 24

    private func makeRig(
        session: WorkoutSessionModel? = nil,
        weightUnit: @escaping (String) -> LiveActivityWeightUnit = { _ in .kilograms }
    ) async throws -> Rig {
        SharedWorkoutStorage.clearRestEndTime()
        let session = session ?? self.session()

        var settings = WorkoutSettings(authorId: "author-1")
        settings.defaultRestDurationSeconds = 90
        settings.restAfterLastWarmUp = true

        let sessions = TestManagers.workoutSessionManager()
        try sessions.updateActiveSession(session)

        let log = SpyLogService()
        let system = SystemActivity()
        let activity = LiveActivityManager(
            logger: LogManager(services: [log]), activityLookup: system.lookup, weightUnit: weightUnit
        )
        system.initialState = activity.makeContentState(session: session, isActive: false, currentExerciseIndex: 0, restEndsAt: nil)
        let hkWorkoutManager = HKWorkoutManager(logger: LogManager(), liveActivityUpdater: activity, restOverNotifier: RestOverNotifierSpy())
        let handler = AppLiveActivityIntentHandler(
            workoutSessionManager: sessions,
            hkWorkoutManager: hkWorkoutManager,
            liveActivityUpdater: activity,
            workoutSettingsManager: try await TestManagers.signedInWorkoutSettingsManager(settings),
            exerciseSettingsManager: TestManagers.exerciseSettingsManager(),
            exerciseModelManager: TestManagers.exerciseModelManager(),
            gymProfileManager: TestManagers.gymProfileManager(),
            trainingProgramManager: TestManagers.trainingProgramManager(),
            userManager: TestManagers.userManager(user: nil)
        )
        return Rig(
            handler: handler, sessions: sessions, hkWorkoutManager: hkWorkoutManager,
            activity: activity, log: log, system: system
        )
    }

    /// Every push reached an activity: the manager found the system's on the first push and no
    /// push was dropped for lack of one. Then takes the activity off the Lock Screen.
    private func expectEveryPushReachedTheActivity(_ rig: Rig) async {
        #expect(rig.system.askedFor.first == "scenario-session", "the manager never asked the system for the activity")
        #expect(rig.system.activity != nil, "the test host could not request an activity")
        #expect(!rig.log.trackedEventNames.contains("LiveActivityMan_UpdateLiveActivity_Fail"), "a push was dropped")
        #expect(!rig.log.trackedEventNames.contains("LiveActivityMan_EndLiveActivity_Fail"), "the end was dropped")
        await rig.system.dismiss()
    }

    /// What the Lock Screen would show for the last state the app pushed.
    private func phase(_ rig: Rig, now: Date = Date(), isStale: Bool = false) throws -> LiveActivityPhase {
        let state = try #require(rig.activity.lastContentState, "the app has pushed nothing")
        return LiveActivityPhase(state: state, now: now, isStale: isStale)
    }

    // MARK: - The whole workout from the Lock Screen

    /// One tap on Complete for whatever the activity currently offers, then whatever the user
    /// would do next: end the rest if one started. Returns the set that was logged and the
    /// exercise the activity moved to. Records an issue if the banner is left with no way forward.
    private func tapComplete(_ rig: Rig, tapNumber: Int, isLast: Bool) async throws -> (setId: String, exerciseIndex: Int) {
        let before = try #require(rig.activity.lastContentState)
        let targetId = try #require(before.targetSetId, "no target to tap for set \(tapNumber)")

        await rig.handler.completeSet(id: targetId)

        let after = try #require(rig.activity.lastContentState)
        switch try phase(rig) {
        case .resting(let until, let next, let logged, _):
            #expect(logged?.setId == targetId)
            if !isLast {
                #expect(next != nil, "resting after set \(tapNumber) shows no next target")
                try expectRestOverOffersAWayForward(rig, restEndsAt: until, tapNumber: tapNumber)
            }
            rig.hkWorkoutManager.endRest()
        case .ready:
            break   // no rest after this one (a warm-up); straight on
        case .allSetsDone:
            #expect(isLast, "all sets done after only \(tapNumber)")
        case let other:
            Issue.record("after set \(tapNumber) (\(targetId)) the activity shows \(other)")
        }
        return (targetId, after.currentExerciseIndex)
    }

    /// Layer 1 of rest expiry: the system re-renders when the stale date passes, before the app
    /// does anything. That render must still offer a set to complete.
    private func expectRestOverOffersAWayForward(_ rig: Rig, restEndsAt: Date, tapNumber: Int) throws {
        let stale = try phase(rig, now: restEndsAt.addingTimeInterval(1), isStale: true)
        guard case .restOver(let next) = stale else {
            Issue.record("stale rest after set \(tapNumber) is not .restOver: \(stale)")
            return
        }
        #expect(!next.isEmpty, "rest over after set \(tapNumber) with an empty target")
    }

    /// Tap Complete on whatever the activity shows, twenty-four times, ending every rest on the
    /// way. The banner must always offer a next set until the last one, must move on to the next
    /// exercise after each last set, and must end on all-sets-done and then the summary.
    @Test("Test A Four Exercise Workout Can Be Completed Entirely From The Activity")
    func testAFourExerciseWorkoutCanBeCompletedEntirelyFromTheActivity() async throws {
        let rig = try await makeRig()
        let session = try #require(rig.sessions.activeSession)
        rig.hkWorkoutManager.startWorkout(workout: session)

        // The app pushes on the first action; seed the activity the way the tracker does on appear.
        rig.activity.updateLiveActivity(params: LiveActivityUpdateParams(
            session: session, isActive: true, currentExerciseIndex: 0, restEndsAt: nil
        ))
        guard case .ready(_, let position) = try phase(rig) else {
            Issue.record("expected .ready at the start, got \(try phase(rig))"); return
        }
        #expect(position.label == "Warmup 1 of 2")

        var completed: [String] = []
        var exerciseIndexAfterEachSet: [Int] = []
        for tap in 1...Self.rowsToTap {
            let step = try await tapComplete(rig, tapNumber: tap, isLast: tap == Self.rowsToTap)
            completed.append(step.setId)
            exerciseIndexAfterEachSet.append(step.exerciseIndex)
            if tap == 2 {
                // Both warm-ups done: the working sets start their own count.
                guard case .ready(_, let position) = try phase(rig) else {
                    Issue.record("expected .ready after the warm-ups, got \(try phase(rig))"); return
                }
                #expect(position.label == "Set 1 of 4")
            }
        }

        #expect(Set(completed).count == Self.rowsToTap, "a row was completed twice")
        // Each exercise's sixth completion moves the activity on, and the index never goes back.
        #expect(exerciseIndexAfterEachSet[5] == 1, "stuck on exercise 1 after its last set")
        #expect(exerciseIndexAfterEachSet[15] == 2, "stuck on the unilateral exercise after its last pair")
        #expect(exerciseIndexAfterEachSet[21] == 3)
        #expect(exerciseIndexAfterEachSet == exerciseIndexAfterEachSet.sorted())

        guard case .allSetsDone = try phase(rig) else {
            Issue.record("after the last set the activity shows \(try phase(rig)) instead of .allSetsDone"); return
        }

        await rig.handler.completeWorkout()

        guard case .ended(let summary) = try phase(rig) else {
            Issue.record("after Finish the activity shows \(try phase(rig)) instead of .ended"); return
        }
        #expect(summary.completedSetsCount == Self.setsDone)
        await expectEveryPushReachedTheActivity(rig)
    }

    /// The same workout with the unilateral exercise last. After the left half of the final pair
    /// the banner must still offer the right row, not "All sets complete" with a Finish button —
    /// the whole-workout totals used to count that lone left row as a finished set.
    @Test("Test A Workout Ending On A Unilateral Exercise Is Not Done After The Left Half Of The Last Pair")
    func testAWorkoutEndingOnAUnilateralExerciseIsNotDoneAfterTheLeftHalfOfTheLastPair() async throws {
        let rows = 6 + 10
        let rig = try await makeRig(session: session(exercises: [exercise(1), exercise(2, unilateral: true)]))
        let session = try #require(rig.sessions.activeSession)
        rig.hkWorkoutManager.startWorkout(workout: session)
        rig.activity.updateLiveActivity(params: LiveActivityUpdateParams(
            session: session, isActive: true, currentExerciseIndex: 0, restEndsAt: nil
        ))

        for tap in 1...rows {
            let step = try await tapComplete(rig, tapNumber: tap, isLast: tap == rows)
            if tap == rows - 1 {
                #expect(step.setId == "e2-s6-left")
                let state = try #require(rig.activity.lastContentState)
                #expect(state.targetSetId == "e2-s6-right")
                #expect(state.isAllSetsComplete == false)
                #expect(state.progress < 1)
            }
        }

        guard case .allSetsDone = try phase(rig) else {
            Issue.record("after the last row the activity shows \(try phase(rig)) instead of .allSetsDone"); return
        }
        await rig.handler.completeWorkout()
        guard case .ended(let summary) = try phase(rig) else {
            Issue.record("after Finish the activity shows \(try phase(rig)) instead of .ended"); return
        }
        #expect(summary.completedSetsCount == 6 + 6)
        await expectEveryPushReachedTheActivity(rig)
    }

    /// Correcting the reps during the rest changes the logged set the banner names, and only that.
    @Test("Test A Reps Correction During The Rest Reaches The Activity")
    func testARepsCorrectionDuringTheRestReachesTheActivity() async throws {
        let rig = try await makeRig()
        rig.hkWorkoutManager.startWorkout(workout: try #require(rig.sessions.activeSession))

        // Through both warm-ups to the first working set.
        for id in ["e1-s1", "e1-s2", "e1-s3"] {
            await rig.handler.completeSet(id: id)
            if rig.hkWorkoutManager.restEndTime != nil, id != "e1-s3" {
                rig.hkWorkoutManager.endRest()
            }
        }
        guard case .resting(_, _, let logged, _) = try phase(rig) else {
            Issue.record("expected to be resting after the first working set, got \(try phase(rig))"); return
        }
        #expect(logged?.setId == "e1-s3")
        #expect(logged?.reps == 8)

        await rig.handler.adjustLastSetReps(id: "e1-s3", delta: -2)

        guard case .resting(_, _, let corrected, _) = try phase(rig) else {
            Issue.record("the correction changed the phase to \(try phase(rig))"); return
        }
        #expect(corrected?.reps == 6, "the activity still shows the uncorrected reps")

        let saved = try #require(rig.sessions.activeSession?.exercises[0].sets.first { $0.id == "e1-s3" })
        #expect(saved.reps == 6)
        #expect(saved.completedAt != nil)
        #expect(saved.weightKg == 65)
        await expectEveryPushReachedTheActivity(rig)
    }

    /// After the last set of an exercise the activity must not point at that exercise: there is
    /// nothing left on it to complete, and a banner with no target has no way forward.
    @Test("Test The Last Set Of An Exercise Moves The Activity To The Next Exercise")
    func testTheLastSetOfAnExerciseMovesTheActivityToTheNextExercise() async throws {
        let rig = try await makeRig()
        rig.hkWorkoutManager.startWorkout(workout: try #require(rig.sessions.activeSession))

        for index in 1...6 {
            await rig.handler.completeSet(id: "e1-s\(index)")
            if rig.hkWorkoutManager.restEndTime != nil, index < 6 {
                rig.hkWorkoutManager.endRest()
            }
        }

        let state = try #require(rig.activity.lastContentState)
        #expect(state.currentExerciseIndex == 1)
        #expect(state.currentExerciseName == "Exercise 2")
        #expect(state.targetSetId == "e2-s1")

        guard case .resting(let until, let next, _, let nextExerciseName) = try phase(rig) else {
            Issue.record("expected a rest before exercise 2, got \(try phase(rig))"); return
        }
        #expect(next != nil)
        #expect(nextExerciseName == "Exercise 2", "the rest into exercise 2 does not name it")
        guard case .restOver(let over) = try phase(rig, now: until.addingTimeInterval(1), isStale: true) else {
            Issue.record("the stale rest is not .restOver"); return
        }
        #expect(!over.isEmpty)
        await expectEveryPushReachedTheActivity(rig)
    }

    /// A per-exercise pounds preference reaches the push a Lock Screen tap makes, and the label
    /// the banner draws from it reads in pounds.
    @Test("Test A Pounds Preference For The Exercise Reaches The Push")
    func testAPoundsPreferenceForTheExerciseReachesThePush() async throws {
        let rig = try await makeRig { $0 == "template-1" ? .pounds : .kilograms }
        rig.hkWorkoutManager.startWorkout(workout: try #require(rig.sessions.activeSession))

        // Warm-ups do not rest between themselves; the rest after the last one is the first push
        // that carries a next target.
        await rig.handler.completeSet(id: "e1-s1")
        await rig.handler.completeSet(id: "e1-s2")

        let state = try #require(rig.activity.lastContentState)
        #expect(state.weightUnit == .pounds)
        guard case .resting(_, let next, _, _) = try phase(rig) else {
            Issue.record("expected a rest after the last warm-up, got \(try phase(rig))"); return
        }
        #expect(next?.label(weightUnit: state.weightUnit)?.hasSuffix("lb × 8") == true)
        await expectEveryPushReachedTheActivity(rig)
    }
}

}

#endif
