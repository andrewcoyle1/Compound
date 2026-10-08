//
//  WorkoutTrackerDeleteExerciseTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// Deleting an exercise, or a set, part-way through: where the card goes, and the rest that
/// followed a set no longer there.
@MainActor
struct WorkoutTrackerDeleteExerciseTests {

    private func set(_ id: String) -> WorkoutSetModel {
        WorkoutSetModel(id: id, authorId: "author-1", index: 1, reps: 5, weightKg: 100, isWarmup: false, dateCreated: Date())
    }

    /// Two open sets per exercise.
    private func makeScreen(_ ids: [String]) throws -> (WorkoutTrackerPresenter, WorkoutTrackerInteractorDouble) {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1", authorId: "author-1", name: "Legs", dateCreated: Date(),
            exercises: ids.enumerated().map { index, id in
                WorkoutExerciseModel(
                    id: id, authorId: "author-1", templateId: "t-\(id)", name: id, trackingMode: .weightReps,
                    index: index + 1, sets: [set("\(id)-1"), set("\(id)-2")]
                )
            }
        )
        return (try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble()), interactor)
    }

    /// "Row" was put off earlier and is first with sets left; the card goes on to "curl", the
    /// one after the deleted exercise, not back to it.
    @Test("Test Deleting The Card's Exercise Moves On To The Next In Order")
    func testCardGoesToNext() throws {
        let (presenter, _) = try makeScreen(["row", "squat", "press", "curl"])
        presenter.onExerciseSelected("press")

        presenter.deleteExercise("press")

        #expect(presenter.currentExercise?.id == "curl")
        #expect(presenter.currentExerciseIndex == 2)
    }

    @Test("Test Deleting The Last Exercise On The Card Wraps To The First With Sets Left")
    func testCardWraps() throws {
        let (presenter, _) = try makeScreen(["squat", "press"])
        presenter.onExerciseSelected("press")

        presenter.deleteExercise("press")

        #expect(presenter.currentExercise?.id == "squat")
    }

    @Test("Test Deleting Another Exercise Leaves The Card Alone")
    func testCardStays() throws {
        let (presenter, _) = try makeScreen(["squat", "press", "curl"])
        presenter.onExerciseSelected("curl")

        presenter.deleteExercise("squat")

        #expect(presenter.currentExercise?.id == "curl")
        #expect(presenter.currentExerciseIndex == 1)
    }

    @Test("Test Deleting The Exercise A Rest Follows Calls The Rest Off")
    func testDeletingRestedExerciseCancelsRest() throws {
        let (presenter, interactor) = try makeScreen(["squat", "press"])
        presenter.onPrimaryActionPressed()
        #expect(interactor.restEndTime != nil)

        presenter.deleteExercise("squat")

        #expect(interactor.didCancelRest)
        #expect(interactor.restEndTime == nil)
    }

    @Test("Test Deleting Another Exercise Keeps The Rest")
    func testDeletingOtherExerciseKeepsRest() throws {
        let (presenter, interactor) = try makeScreen(["squat", "press"])
        presenter.onPrimaryActionPressed()

        presenter.deleteExercise("press")

        #expect(!interactor.didCancelRest)
        #expect(interactor.restEndTime != nil)
    }

    /// What the row's swipe does: the set leaves the session through the binding.
    @Test("Test Deleting The Set A Rest Follows Calls The Rest Off")
    func testDeletingRestedSetCancelsRest() throws {
        let (presenter, interactor) = try makeScreen(["squat", "press"])
        presenter.onPrimaryActionPressed()

        presenter.workoutSession.exercises[0].sets.removeFirst()

        #expect(interactor.didCancelRest)
        #expect(presenter.restTimer(for: presenter.workoutSession.exercises[0]) == nil)
    }
}
