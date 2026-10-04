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

    // MARK: - The hint

    /// The header says what the engine decided, in one line and in the user's words.
    @Test("Test The Header Hint Reads From The Rationale")
    func testTheHeaderHintReadsFromTheRationale() throws {
        let screen = try makeScreen(sets: [set(1), set(2), set(3)])
        screen.presenter.progressionSuggestions = [
            "template-exercise-1": ProgressionSuggestion(rationale: .progressWeight, sets: [])
        ]

        #expect(screen.presenter.progressionHint(for: "exercise-1") == "Smart Progression: add weight")
    }

    /// Nothing to go on, nothing to say.
    @Test("Test There Is No Hint Without History")
    func testThereIsNoHintWithoutHistory() throws {
        let screen = try makeScreen(sets: [set(1), set(2), set(3)])
        screen.presenter.progressionSuggestions = [
            "template-exercise-1": .noHistory(setCount: 3)
        ]

        #expect(screen.presenter.progressionHint(for: "exercise-1") == nil)
    }
}
