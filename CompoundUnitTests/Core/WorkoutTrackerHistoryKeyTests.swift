//
//  WorkoutTrackerHistoryKeyTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 07/10/2026.
//

import Testing
import Foundation
@testable import Compound

/// The same exercise twice in one workout (a heavy 6–8 set, then a 1 × 20 back-off) has a last
/// time and a suggestion for each appearance (`ActiveWorkout.historyKey`). The first appearance
/// reads exactly what it always did.
@MainActor
struct WorkoutTrackerHistoryKeyTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(_ id: String, reps: Int, weightKg: Double, done: Bool = true) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: 1, reps: reps, weightKg: weightKg,
            isWarmup: false, completedAt: done ? start : nil, dateCreated: start
        )
    }

    private func exercise(_ id: String, templateId: String, index: Int, sets: [WorkoutSetModel] = []) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: id, authorId: "author-1", templateId: templateId, name: templateId,
            trackingMode: .weightReps, index: index, sets: sets
        )
    }

    /// Bench, row, bench.
    private var today: [WorkoutExerciseModel] {
        [
            exercise("heavy", templateId: "bench", index: 1),
            exercise("row", templateId: "row", index: 2),
            exercise("backoff", templateId: "bench", index: 3)
        ]
    }

    private func lastSession(_ exercises: [WorkoutExerciseModel]) -> WorkoutSessionModel {
        WorkoutSessionModel(
            id: "last", authorId: "author-1", name: "Push", workoutTemplateId: "template-1",
            dateCreated: start, endedAt: start, exercises: exercises
        )
    }

    private func makePresenter() throws -> (WorkoutTrackerPresenter, WorkoutTrackerInteractorDouble) {
        let interactor = WorkoutTrackerInteractorDouble()
        interactor.activeSession = WorkoutSessionModel(
            id: "session-1", authorId: "author-1", name: "Push", workoutTemplateId: "template-1",
            dateCreated: start, exercises: today
        )
        return (try WorkoutTrackerPresenter(interactor: interactor, router: WorkoutTrackerRouterDouble()), interactor)
    }

    private func exercise(_ id: String, in presenter: WorkoutTrackerPresenter) throws -> WorkoutExerciseModel {
        try #require(presenter.workoutSession.exercises.first { $0.id == id })
    }

    // MARK: - The key

    @Test("Test Each Appearance Has Its Own Key")
    func testEachAppearanceHasItsOwnKey() {
        let session = WorkoutSessionModel(id: "s", authorId: "author-1", name: "Push", dateCreated: start, exercises: today)

        #expect(ActiveWorkout.historyKey(for: today[0], in: session) == "bench#0")
        #expect(ActiveWorkout.historyKey(for: today[1], in: session) == "row#0")
        #expect(ActiveWorkout.historyKey(for: today[2], in: session) == "bench#1")
    }

    // MARK: - Last time

    @Test("Test The Second Appearance Gets Its Own Last Time")
    func testTheSecondAppearanceGetsItsOwnLastTime() async throws {
        let (presenter, interactor) = try makePresenter()
        interactor.completedSessions = [lastSession([
            exercise("last-heavy", templateId: "bench", index: 1, sets: [set("h1", reps: 8, weightKg: 100)]),
            exercise("last-row", templateId: "row", index: 2),
            exercise("last-backoff", templateId: "bench", index: 3, sets: [set("b1", reps: 20, weightKg: 60)])
        ])]

        presenter.loadPreviousWorkoutSession()

        let heavy = try exercise("heavy", in: presenter)
        let backoff = try exercise("backoff", in: presenter)
        #expect(await TestManagers.eventually { presenter.previousExercise(for: backoff)?.id == "last-backoff" })
        #expect(presenter.previousExercise(for: heavy)?.id == "last-heavy")
        #expect(presenter.previousNote(for: backoff) == nil)
    }

    /// Done once last time: the first appearance reads it as it always did, and the second has no
    /// last time rather than borrowing the heavy set's.
    @Test("Test A Second Appearance Never Done Before Has No Last Time")
    func testASecondAppearanceNeverDoneBeforeHasNoLastTime() async throws {
        let (presenter, interactor) = try makePresenter()
        interactor.completedSessions = [lastSession([
            exercise("last-heavy", templateId: "bench", index: 1, sets: [set("h1", reps: 8, weightKg: 100)])
        ])]

        presenter.loadPreviousWorkoutSession()

        let heavy = try exercise("heavy", in: presenter)
        #expect(await TestManagers.eventually { presenter.previousExercise(for: heavy)?.id == "last-heavy" })
        #expect(presenter.previousExercises.keys.sorted() == ["bench#0"])
    }

    // MARK: - Suggestions

    @Test("Test The Second Appearance Reads Its Own Suggestion")
    func testTheSecondAppearanceReadsItsOwnSuggestion() async throws {
        let (presenter, interactor) = try makePresenter()
        interactor.progressionSuggestionsByTemplateId["bench#0"] = ProgressionSuggestion(rationale: .progressWeight, sets: [SuggestedSet(weightKg: 102.5, reps: 6)])
        interactor.progressionSuggestionsByTemplateId["bench#1"] = ProgressionSuggestion(rationale: .hold, sets: [SuggestedSet(weightKg: 60, reps: 20)])

        presenter.loadProgressionSuggestions()

        let heavy = try exercise("heavy", in: presenter)
        let backoff = try exercise("backoff", in: presenter)
        #expect(await TestManagers.eventually { presenter.progressionSuggestion(for: backoff)?.rationale == .hold })
        #expect(presenter.progressionSuggestion(for: heavy)?.rationale == .progressWeight)
    }

    /// Through the planner: the heavy set reached the top of its range and earns weight; the
    /// back-off missed its twenty and holds. Read by template alone, both would progress.
    @Test("Test The Planner Suggests For Each Appearance From Its Own History")
    func testThePlannerSuggestsForEachAppearanceFromItsOwnHistory() {
        let history = [lastSession([
            exercise("last-heavy", templateId: "bench", index: 1, sets: [set("h1", reps: 8, weightKg: 100)]),
            exercise("last-backoff", templateId: "bench", index: 2, sets: [set("b1", reps: 15, weightKg: 60)])
        ])]
        let contexts = [
            ProgressionPlanner.ExerciseContext(
                templateId: "bench", trackingMode: .weightReps,
                setTargets: [SetTarget(setNumber: 1, minReps: 6, maxReps: 8)],
                exercise: nil, preferredWeightUnit: .kilograms
            ),
            ProgressionPlanner.ExerciseContext(
                templateId: "bench", trackingMode: .weightReps,
                setTargets: [SetTarget(setNumber: 1, minReps: 20, maxReps: 20)],
                exercise: nil, preferredWeightUnit: .kilograms, occurrence: 1
            )
        ]

        let suggestions = ProgressionPlanner.suggestions(
            for: contexts, history: history, adjustmentMode: .weightFirst, gymProfile: nil
        )

        #expect(suggestions.keys.sorted() == ["bench#0", "bench#1"])
        #expect(suggestions["bench#0"]?.rationale == .progressWeight)
        #expect(suggestions["bench#1"]?.rationale != .progressWeight)
        #expect(suggestions["bench#1"]?.sets.first?.weightKg == 60)
    }
}
