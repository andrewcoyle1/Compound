//
//  WorkoutTrackerSwapTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 06/10/2026.
//

import Testing
import Foundation
@testable import Compound

/// Swapping an exercise mid-workout from the card's menu (`insertSwappedExercise`).
///
/// It used to rename the exercise in place, so two logged sets of barbell bench became dumbbell
/// bench in the history, last time's figures and the suggestion vanished (both are keyed by the
/// old template), and an open warm-up came back as an extra working set.
@MainActor
struct WorkoutTrackerSwapTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(_ id: String, index: Int, done: Bool = false, warmup: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id,
            authorId: "author-1",
            index: index,
            reps: 8,
            weightKg: 80,
            isWarmup: warmup,
            completedAt: done ? start : nil,
            dateCreated: start
        )
    }

    private func exercise(id: String, index: Int, sets: [WorkoutSetModel], supersetGroupId: String? = nil) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: id,
            authorId: "author-1",
            templateId: "template-\(id)",
            name: "Barbell Bench Press",
            trackingMode: .weightReps,
            index: index,
            sets: sets,
            setTargets: (1...3).map { SetTarget(setNumber: $0, minReps: $0 * 2, maxReps: $0 * 2 + 2) },
            supersetGroupId: supersetGroupId
        )
    }

    /// A warm-up and a working set logged, a warm-up and two working sets still open.
    private var halfDone: WorkoutExerciseModel {
        exercise(id: "e1", index: 1, sets: [
            set("w1", index: 1, done: true, warmup: true),
            set("w2", index: 2, warmup: true),
            set("s1", index: 3, done: true),
            set("s2", index: 4),
            set("s3", index: 5)
        ])
    }

    private func replacement() throws -> ExerciseModel {
        try #require(ExerciseModel.mocks.first { !WorkoutSessionModel.isPerSide($0) })
    }

    private func makePresenter(_ exercises: [WorkoutExerciseModel]) throws -> (WorkoutTrackerPresenter, WorkoutTrackerInteractorDouble) {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1",
            authorId: "author-1",
            name: "Push Day",
            dateCreated: start,
            exercises: exercises
        )
        return (try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble()), interactor)
    }

    // MARK: - The rule

    @Test("Test Logged Sets Stay On The Old Exercise")
    func testLoggedSetsStayOnTheOldExercise() throws {
        let swap = WorkoutTrackerPresenter.swapping(halfDone, to: try replacement(), authorId: "author-1")

        let kept = try #require(swap.kept)
        #expect(kept.id == "e1")
        #expect(kept.templateId == "template-e1")
        #expect(kept.sets.map(\.id) == ["w1", "s1"])
        #expect(kept.sets.allSatisfy { $0.completedAt != nil })
    }

    /// Two working sets were open, so the replacement has two: the open warm-up was preparation
    /// for the old lift and does not become a working set of the new one.
    @Test("Test The Replacement Takes The Open Working Sets Only")
    func testTheReplacementTakesTheOpenWorkingSetsOnly() throws {
        let new = try replacement()
        let swap = WorkoutTrackerPresenter.swapping(halfDone, to: new, authorId: "author-1")

        #expect(swap.replacement.id != "e1")
        #expect(swap.replacement.templateId == new.id)
        #expect(swap.replacement.name == new.name)
        #expect(swap.replacement.sets.count == 2)
        #expect(swap.replacement.sets.allSatisfy { $0.completedAt == nil && !$0.isWarmup })
        #expect(swap.replacement.sets.map(\.index) == [1, 2])
    }

    /// Set 1 was logged, so the replacement's set 1 is the old set 2 and takes its target.
    @Test("Test The Replacement Takes The Targets Of The Open Sets")
    func testTheReplacementTakesTheTargetsOfTheOpenSets() throws {
        let swap = WorkoutTrackerPresenter.swapping(halfDone, to: try replacement(), authorId: "author-1")

        #expect(swap.replacement.setTargets.map(\.setNumber) == [1, 2])
        #expect(swap.replacement.setTargets.map(\.minReps) == [4, 6])
    }

    @Test("Test With Nothing Logged The Replacement Takes The Exercises Place")
    func testWithNothingLoggedTheReplacementTakesTheExercisesPlace() throws {
        let fresh = exercise(id: "e1", index: 1, sets: [set("s1", index: 1), set("s2", index: 2), set("s3", index: 3), set("s4", index: 4)])

        let swap = WorkoutTrackerPresenter.swapping(fresh, to: try replacement(), authorId: "author-1")

        #expect(swap.kept == nil)
        #expect(swap.replacement.id == "e1")
        #expect(swap.replacement.sets.count == 4)
    }

    // MARK: - On the screen

    @Test("Test The Replacement Goes In Right After The Old Exercise")
    func testTheReplacementGoesInRightAfterTheOldExercise() throws {
        let new = try replacement()
        let (presenter, _) = try makePresenter([halfDone, exercise(id: "e2", index: 2, sets: [set("e2-s1", index: 1)])])

        presenter.insertSwappedExercise(after: "e1", new: new)

        let exercises = presenter.workoutSession.exercises
        #expect(exercises.count == 3)
        #expect(exercises[0].id == "e1")
        #expect(exercises[1].templateId == new.id)
        #expect(exercises[2].id == "e2")
        #expect(exercises.map(\.index) == [1, 2, 3])
        #expect(presenter.isComplete(exercises[0]))
        #expect(presenter.currentExercise?.id == exercises[1].id)
    }

    /// The old exercise is done and out of the group; the replacement is the one paired now.
    @Test("Test The Replacement Takes The Old Exercises Place In A Superset")
    func testTheReplacementTakesTheOldExercisesPlaceInASuperset() throws {
        var old = halfDone
        old.supersetGroupId = "group-1"
        let partner = exercise(id: "e2", index: 2, sets: [set("e2-s1", index: 1)], supersetGroupId: "group-1")
        let (presenter, _) = try makePresenter([old, partner])

        presenter.insertSwappedExercise(after: "e1", new: try replacement())

        let grouped = presenter.workoutSession.exercises.filter { $0.supersetGroupId == "group-1" }
        #expect(grouped.count == 2)
        #expect(!grouped.contains { $0.id == "e1" })
    }

    /// Last time's figures and the suggestion are keyed by template, so they are loaded for the
    /// replacement rather than left blank.
    @Test("Test Last Time And Suggestions Load For The Replacement")
    func testLastTimeAndSuggestionsLoadForTheReplacement() async throws {
        let new = try replacement()
        let (presenter, interactor) = try makePresenter([halfDone])
        interactor.progressionSuggestionsByTemplateId[new.id] = .noHistory(setCount: 2)
        interactor.completedSessions = [
            WorkoutSessionModel(
                id: "last-time",
                authorId: "author-1",
                name: "Push Day",
                dateCreated: start,
                endedAt: start,
                exercises: [
                    WorkoutExerciseModel(id: "last-\(new.id)", authorId: "author-1", templateId: new.id, name: new.name, trackingMode: .weightReps, index: 1, sets: [])
                ]
            )
        ]

        presenter.insertSwappedExercise(after: "e1", new: new)

        #expect(await TestManagers.eventually { presenter.previousExercises[new.id]?.id == "last-\(new.id)" })
        #expect(await TestManagers.eventually { presenter.progressionSuggestions[new.id] != nil })
    }
}
