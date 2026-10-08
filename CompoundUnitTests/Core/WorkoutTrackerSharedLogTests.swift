//
//  WorkoutTrackerSharedLogTests.swift
//  CompoundUnitTests
//
//  The tracker's half of the one log rule it shares with the Live Activity: the focus both keep
//  in the screen state, a set logged elsewhere re-suggesting what is left, and the activity
//  counting and naming sets as the tracker does.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct WorkoutTrackerSharedLogTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(_ id: String, index: Int, reps: Int? = 8, side: SetSide? = nil, warmup: Bool = false, done: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: index, reps: reps, weightKg: 60, side: side,
            isWarmup: warmup, completedAt: done ? start : nil, dateCreated: start
        )
    }

    private func exercise(_ id: String, sets: [WorkoutSetModel], group: String? = nil) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: id, authorId: "author-1", templateId: "template-\(id)", name: id.uppercased(), trackingMode: .weightReps,
            index: 1, sets: sets,
            setTargets: (1...3).map { SetTarget(id: "target-\($0)", setNumber: $0, minReps: 8, maxReps: 12) },
            supersetGroupId: group
        )
    }

    private func screen(_ exercises: [WorkoutExerciseModel], configure: (WorkoutTrackerInteractorDouble) -> Void = { _ in }) throws
        -> (presenter: WorkoutTrackerPresenter, interactor: WorkoutTrackerInteractorDouble) {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.workoutSettings.propagateChanges = false
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1", authorId: "author-1", name: "Push Day", dateCreated: start, exercises: exercises
        )
        configure(interactor)
        let presenter = try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble(), saveRetryBackoff: .testImmediate)
        return (presenter, interactor)
    }

    private func storedFocus(_ interactor: WorkoutTrackerInteractorDouble) -> String? {
        ActiveWorkoutScreenState.load(sessionId: "session-1", from: interactor.activeWorkoutScreenStateStore).focusExerciseId
    }

    private var superset: [WorkoutExerciseModel] {
        [
            exercise("a", sets: [set("a1", index: 1), set("a2", index: 2)], group: "g"),
            exercise("b", sets: [set("b1", index: 1), set("b2", index: 2)], group: "g")
        ]
    }

    // MARK: - Focus in the screen state

    /// A1 logged on the phone moves the card to B and keeps it where the Live Activity reads it.
    @Test("Test Logging On The Phone Keeps The Focus For The Lock Screen")
    func testLoggingKeepsFocus() throws {
        let (presenter, interactor) = try screen(superset)

        presenter.logSet("a1", in: "a")

        #expect(presenter.currentExercise?.id == "b")
        #expect(storedFocus(interactor) == "b")
    }

    /// The tracker's other screen state is written without the focus, and keeps it.
    @Test("Test Saving The Other Screen State Keeps The Focus")
    func testOtherScreenStateKeepsFocus() throws {
        let (presenter, interactor) = try screen(superset)
        presenter.logSet("a1", in: "a")

        presenter.customRestSeconds["b1"] = 45

        #expect(storedFocus(interactor) == "b")
    }

    /// A tracker rebuilt after a minimise opens where the Lock Screen left off, not on the first
    /// exercise with sets left.
    @Test("Test A Rebuilt Tracker Opens On The Stored Focus")
    func testRebuiltTrackerRestoresFocus() throws {
        let (_, interactor) = try screen(superset)
        ActiveWorkoutScreenState(sessionId: "session-1", focusExerciseId: "b").save(to: interactor.activeWorkoutScreenStateStore)

        let rebuilt = try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble(), saveRetryBackoff: .testImmediate)

        #expect(rebuilt.currentExercise?.id == "b")
    }

    // MARK: - Logged elsewhere

    /// A set logged from the Lock Screen and adopted here re-suggests the sets still to come, once.
    @Test("Test An Adopted Remote Log Runs Live Progression Once")
    func testAdoptedRemoteLogRunsProgression() throws {
        let (presenter, interactor) = try screen([
            exercise("a", sets: [set("a1", index: 1), set("a2", index: 2), set("a3", index: 3)])
        ]) { $0.workoutSettings.smartProgressionApplyInSession = true }

        var saved = try #require(interactor.activeSession)
        saved.exercises[0].sets[0].reps = 6
        saved.exercises[0].sets[0].completedAt = start
        interactor.activeSession = saved
        presenter.adoptSavedSessionIfChanged()

        let remaining = presenter.workoutSession.exercises[0].sets.dropFirst()
        #expect(remaining.allSatisfy { $0.weightKg == 57 && $0.reps == 8 })
        #expect(interactor.trackedEventNames.filter { $0 == "WorkoutTracker_Progression_Adjusted" }.count == 1)
    }

    // MARK: - What the activity shows

    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)

    private func contentState(_ exercises: [WorkoutExerciseModel]) -> WorkoutActivityAttributes.ContentState {
        let session = WorkoutSessionModel(id: "session-1", authorId: "author-1", name: "Push Day", dateCreated: start, exercises: exercises)
        return LiveActivityManager(logger: LogManager()).makeContentState(session: session, isActive: true, currentExerciseIndex: 0, restEndsAt: nil)
    }

    /// Warm-ups are left out of the totals, as the tracker's header leaves them out.
    @Test("Test The Activity Counts Working Sets Only")
    func testWorkingSetCounts() {
        let state = contentState([exercise("a", sets: [
            set("w1", index: 1, warmup: true, done: true),
            set("a1", index: 2, done: true),
            set("a2", index: 3)
        ])])

        #expect(state.completedSetsCount == 1)
        #expect(state.totalSetsCount == 2)
        #expect(!state.isAllSetsComplete)
    }

    /// The side of a split set reaches the banner: "Set 1L of 2", then "Set 1R of 2".
    @Test("Test The Activity Names The Side")
    func testSideReachesTheBanner() {
        let left = contentState([exercise("a", sets: [
            set("l1", index: 1, side: .left), set("r1", index: 2, side: .right),
            set("l2", index: 3, side: .left), set("r2", index: 4, side: .right)
        ])])
        #expect(left.targetSide == "L")
        #expect(LiveActivityPhase(state: left, now: start, isStale: false)
            == .ready(target: LiveActivitySetTarget(weightKg: 60, reps: 8), position: SetPosition(index: 1, total: 2, side: "L")))
        #expect(SetPosition(index: 1, total: 2, side: "R").label == "Set 1R of 2")

        let both = contentState([exercise("a", sets: [set("b1", index: 1, side: .both)])])
        #expect(both.targetSide == nil)
    }

    /// Complete is offered only for a set the app would log.
    @Test("Test Complete Is Disabled For A Set That Is Not Ready")
    func testCanComplete() {
        #expect(contentState([exercise("a", sets: [set("a1", index: 1)])]).canComplete)
        #expect(!contentState([exercise("a", sets: [set("a1", index: 1, reps: nil)])]).canComplete)
    }

    #endif
}
