//
//  WorkoutTrackerPresenterProgressionTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// Smart progression on the live screen.
///
/// Two rules decide everything here. **The toggle is the toggle**: with
/// `smartProgressionApplyInSession` off, finishing a set changes nothing at all. And **the user
/// wins**: a set they have typed over is theirs, so only the sets still holding the values the
/// screen filled in may be re-suggested. Anything else would rewrite a number somebody chose
/// while they were looking at it.
@MainActor
struct WorkoutTrackerPresenterProgressionTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private struct Screen {
        let presenter: WorkoutTrackerPresenter
        let interactor: WorkoutTrackerInteractorDouble
    }

    private func set(_ index: Int, reps: Int? = 8, weightKg: Double? = 60, done: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)",
            authorId: "author-1",
            index: index,
            reps: reps,
            weightKg: weightKg,
            isWarmup: false,
            completedAt: done ? start : nil,
            dateCreated: start
        )
    }

    private func exercise(sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "exercise-1",
            authorId: "author-1",
            templateId: "template-exercise-1",
            name: "Bench Press",
            trackingMode: .weightReps,
            index: 1,
            sets: sets,
            setTargets: (1...3).map { SetTarget(id: "target-\($0)", setNumber: $0, minReps: 8, maxReps: 12) }
        )
    }

    private func makeScreen(
        sets: [WorkoutSetModel],
        applyInSession: Bool = true
    ) throws -> Screen {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.workoutSettings.smartProgressionApplyInSession = applyInSession
        // Off, so the reps typed into set one stay there and only progression moves the rest.
        interactor.workoutSettings.propagateChanges = false
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Push Day",
            workoutTemplateId: "template-1",
            dateCreated: start,
            exercises: [exercise(sets: sets)]
        )

        return Screen(
            presenter: try WorkoutTrackerPresenter(
                interactor: interactor,
                router: WorkoutTrackerRouterDouble(),
                saveRetryBackoff: .testImmediate
            ),
            interactor: interactor
        )
    }

    /// Marks set one done at `reps`, the way the row does, and hands the presenter the result.
    private func completeFirstSet(_ presenter: WorkoutTrackerPresenter, reps: Int) {
        presenter.workoutSession.exercises[0].sets[0].reps = reps
        presenter.workoutSession.exercises[0].sets[0].completedAt = start
        presenter.applyLiveProgression(after: presenter.workoutSession.exercises[0].sets[0], in: "exercise-1")
    }

    private func remainingValues(_ presenter: WorkoutTrackerPresenter) -> [(weight: Double?, reps: Int?)] {
        presenter.workoutSession.exercises[0].sets.dropFirst().map { ($0.weightKg, $0.reps) }
    }

    // MARK: - Live adjustment

    /// Missing the bottom of the range by two lightens what is left — but the second set has been
    /// edited to 55 kg by hand, so it keeps the number the user typed while the third moves.
    @Test("Test A Set The User Edited Is Not Overwritten")
    func testASetTheUserEditedIsNotOverwritten() throws {
        let screen = try makeScreen(sets: [set(1), set(2), set(3)])
        screen.presenter.workoutSession.exercises[0].sets[1].weightKg = 55

        completeFirstSet(screen.presenter, reps: 6)

        let remaining = remainingValues(screen.presenter)
        #expect(remaining[0].weight == 55)
        #expect(remaining[0].reps == 8)
        #expect(remaining[1].weight == 57)
        #expect(remaining[1].reps == 8)
    }

    /// With every set untouched, both of the ones still to come are re-suggested.
    @Test("Test Untouched Sets Are Re-Suggested")
    func testUntouchedSetsAreReSuggested() throws {
        let screen = try makeScreen(sets: [set(1), set(2), set(3)])

        completeFirstSet(screen.presenter, reps: 6)

        let allLightened = remainingValues(screen.presenter).allSatisfy { $0.weight == 57 && $0.reps == 8 }
        #expect(allLightened)
    }

    /// The setting is off by default, and off means nothing runs.
    @Test("Test Nothing Is Adjusted With The Setting Off")
    func testNothingIsAdjustedWithTheSettingOff() throws {
        let screen = try makeScreen(sets: [set(1), set(2), set(3)], applyInSession: false)

        completeFirstSet(screen.presenter, reps: 6)

        let allUnchanged = remainingValues(screen.presenter).allSatisfy { $0.weight == 60 && $0.reps == 8 }
        #expect(allUnchanged)
    }

    /// A set already logged is history, not a suggestion, so it is left where it is.
    @Test("Test A Set Already Logged Is Not Adjusted")
    func testASetAlreadyLoggedIsNotAdjusted() throws {
        let screen = try makeScreen(sets: [set(1), set(2, done: true), set(3)])

        completeFirstSet(screen.presenter, reps: 6)

        let remaining = remainingValues(screen.presenter)
        #expect(remaining[0].weight == 60)
        #expect(remaining[1].weight == 57)
    }

    /// Assistance is stored negative, so the same rule takes help away: −30 kg done for 14 reps,
    /// two past the top of 8–12, suggests −27.5 kg for what is left — a harder set, not an easier.
    @Test("Test An Assisted Set Progresses To Less Assistance")
    func testAnAssistedSetProgressesToLessAssistance() throws {
        let screen = try makeScreen(sets: [set(1, weightKg: -30), set(2, weightKg: -30), set(3, weightKg: -30)])

        completeFirstSet(screen.presenter, reps: 14)

        let lessHelp = remainingValues(screen.presenter).allSatisfy { $0.weight == -27.5 && $0.reps == 8 }
        #expect(lessHelp)
    }

    // MARK: - Minimise and reopen

    /// Minimising releases the presenter and reopening builds a new one. The new one used to
    /// capture its baseline from the values on screen, so the 55 kg typed before the minimise
    /// read as the engine's own and was overwritten. The baseline is now the one first captured.
    @Test("Test Minimise And Rebuild Keeps An Edited Set Out Of Live Re-Suggestion")
    func testMinimiseKeepsEditedSetOutOfReSuggestion() throws {
        let screen = try makeScreen(sets: [set(1), set(2), set(3)])
        screen.presenter.workoutSession.exercises[0].sets[1].weightKg = 55
        screen.presenter.minimizeSession()

        let reopened = try WorkoutTrackerPresenter(interactor: screen.interactor, router: WorkoutTrackerRouterDouble())
        #expect(reopened.workoutSession.exercises[0].sets[1].weightKg == 55)
        completeFirstSet(reopened, reps: 6)

        let remaining = remainingValues(reopened)
        #expect(remaining[0].weight == 55)
        #expect(remaining[1].weight == 57)
    }

    @Test("Test A Reopened Tracker Keeps Dismissed Notes And Rests Set By Hand")
    func testReopenedTrackerKeepsScreenState() throws {
        let screen = try makeScreen(sets: [set(1), set(2), set(3)])
        screen.presenter.onProgressionNoteAcknowledged()
        screen.presenter.customRestSeconds["set-2"] = 200
        screen.presenter.minimizeSession()

        let reopened = try WorkoutTrackerPresenter(interactor: screen.interactor, router: WorkoutTrackerRouterDouble())

        #expect(reopened.acknowledgedProgressionNotes == ["template-exercise-1"])
        #expect(reopened.customRestSeconds == ["set-2": 200])
    }

    /// The same store holding another workout's state hands none of it to this one.
    @Test("Test Another Workout's Screen State Is Not Picked Up")
    func testAnotherWorkoutsStateIgnored() throws {
        let screen = try makeScreen(sets: [set(1), set(2)])
        ActiveWorkoutScreenState(
            sessionId: "session-0",
            acknowledgedNoteTemplateIds: ["template-exercise-1"],
            customRestSeconds: ["set-1": 200]
        ).save(to: screen.interactor.activeWorkoutScreenStateStore)

        let reopened = try WorkoutTrackerPresenter(interactor: screen.interactor, router: WorkoutTrackerRouterDouble())

        #expect(reopened.acknowledgedProgressionNotes.isEmpty)
        #expect(reopened.customRestSeconds.isEmpty)
        #expect(reopened.progressionBaseline["set-1"] == SuggestedSet(weightKg: 60, reps: 8))
    }

    // MARK: - WP-S3: the set plan's note

    /// With the set plan on, an exercise that opens with an AMRAP target says so over its sets,
    /// until the note is read; with it off, the same session shows no note.
    @Test("Test The Plan Note Shows Once With The Switch On And Is Acknowledged")
    func testThePlanNoteShowsOnceAndIsAcknowledged() throws {
        var amrap = set(3)
        amrap.kind = .amrap
        amrap.targetReps = 8
        let screen = try makeScreen(sets: [set(1), set(2), amrap])
        #expect(screen.presenter.progressionNote == nil)

        screen.interactor.workoutSettings.setPlanning = true
        #expect(screen.presenter.progressionNote == "Set 3 is AMRAP, target 8+.")

        screen.presenter.onProgressionNoteAcknowledged()
        #expect(screen.presenter.progressionNote == nil)
        #expect(screen.presenter.acknowledgedProgressionNotes == ["template-exercise-1"])
    }

    /// Once the first working set is logged the plan is under way, and the note has had its moment.
    @Test("Test The Plan Note Goes Once A Working Set Is Logged")
    func testThePlanNoteGoesOnceAWorkingSetIsLogged() throws {
        var amrap = set(2)
        amrap.kind = .amrap
        amrap.targetReps = 8
        let screen = try makeScreen(sets: [set(1, done: true), amrap])
        screen.interactor.workoutSettings.setPlanning = true

        #expect(screen.presenter.progressionNote == nil)
    }
}
