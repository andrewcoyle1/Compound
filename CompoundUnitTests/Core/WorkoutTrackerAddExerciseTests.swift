//
//  WorkoutTrackerAddExerciseTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// An exercise added part-way through is set up as the workout's own were: rows a unilateral lift
/// can split, last time's sets, a suggestion. Adding it leaves the card where it was.
@MainActor
struct WorkoutTrackerAddExerciseTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func openSet(_ id: String) -> WorkoutSetModel {
        WorkoutSetModel(id: id, authorId: "author-1", index: 1, reps: 5, weightKg: 100, isWarmup: false, dateCreated: start)
    }

    private func makeScreen() throws -> (WorkoutTrackerPresenter, WorkoutTrackerInteractorDouble) {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Legs",
            dateCreated: start,
            exercises: ["squat", "press"].enumerated().map { index, id in
                WorkoutExerciseModel(
                    id: id, authorId: "author-1", templateId: "t-\(id)", name: id, trackingMode: .weightReps,
                    index: index + 1, sets: [openSet("\(id)-1"), openSet("\(id)-2")]
                )
            }
        )
        return (try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble()), interactor)
    }

    /// A one-arm row: its metrics say one side at a time.
    private var oneArmRow: WorkoutTemplateExercise {
        var exercise = ExerciseModel.mock
        exercise.id = "one-arm-row"
        exercise.name = "One-Arm Row"
        exercise.trackableMetrics = [.weight, .repsPerSide]
        return WorkoutTemplateExercise(
            exercise: exercise,
            setTargets: (1...3).map { SetTarget(setNumber: $0) },
            setRestTimers: false
        )
    }

    private func added(_ presenter: WorkoutTrackerPresenter) throws -> WorkoutExerciseModel {
        try #require(presenter.workoutSession.exercises.first { $0.templateId == "one-arm-row" })
    }

    @Test("Test A Unilateral Exercise Added Mid-Workout Gets Rows It Can Split")
    func testPerSideRows() throws {
        let (presenter, _) = try makeScreen()
        presenter.pendingSelectedTemplates = [oneArmRow]

        presenter.addSelectedExercises()

        let row = try added(presenter)
        #expect(row.sets.count == 3)
        #expect(row.sets.allSatisfy { $0.side == .both })
        #expect(presenter.pendingSelectedTemplates.isEmpty)
    }

    @Test("Test An Added Exercise Loads Last Time And Its Suggestion, Keeping The Others'")
    func testLastAndSuggestionLoaded() async throws {
        let (presenter, interactor) = try makeScreen()
        presenter.previousExercises["t-squat#0"] = WorkoutExerciseModel(
            id: "kept", authorId: "author-1", templateId: "t-squat", name: "squat", trackingMode: .weightReps, index: 1, sets: []
        )
        interactor.completedSessions = [WorkoutSessionModel(
            id: "last-week",
            authorId: "author-1",
            name: "Back",
            dateCreated: start,
            endedAt: start,
            exercises: [WorkoutExerciseModel(
                id: "last-row", authorId: "author-1", templateId: "one-arm-row", name: "One-Arm Row", trackingMode: .weightReps, index: 1,
                sets: [WorkoutSetModel(id: "l1", authorId: "author-1", index: 1, reps: 10, weightKg: 30, isWarmup: false, completedAt: start, dateCreated: start)]
            )]
        )]
        interactor.progressionSuggestionsByTemplateId["one-arm-row"] = ProgressionSuggestion(
            rationale: .progressWeight, sets: [SuggestedSet(weightKg: 32.5, reps: 10)]
        )
        presenter.pendingSelectedTemplates = [oneArmRow]

        presenter.addSelectedExercises()

        #expect(await TestManagers.eventually(timeout: .seconds(5)) {
            presenter.previousExercises["one-arm-row#0"]?.id == "last-row"
                && presenter.progressionSuggestions["one-arm-row#0"] != nil
        })
        #expect(presenter.previousExercises["t-squat#0"]?.id == "kept")
    }

    @Test("Test Adding An Exercise Leaves The Card Where It Was")
    func testCardStays() throws {
        let (presenter, _) = try makeScreen()
        presenter.onExerciseSelected("press")
        presenter.pendingSelectedTemplates = [oneArmRow]

        presenter.addSelectedExercises()

        #expect(presenter.currentExercise?.id == "press")
        #expect(presenter.workoutSession.exercises.last?.templateId == "one-arm-row")
    }

    /// Nothing on the card yet: the first exercise added goes there.
    @Test("Test The First Exercise Added To An Empty Workout Goes On The Card")
    func testEmptyWorkout() throws {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = WorkoutSessionModel(id: "session-1", authorId: "author-1", name: "Legs", dateCreated: start, exercises: [])
        let presenter = try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble())
        presenter.pendingSelectedTemplates = [oneArmRow]

        presenter.addSelectedExercises()

        #expect(presenter.currentExercise?.templateId == "one-arm-row")
    }
}
