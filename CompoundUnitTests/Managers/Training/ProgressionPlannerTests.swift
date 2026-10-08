//
//  ProgressionPlannerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 07/10/2026.
//

import Testing
import Foundation
@testable import Compound

/// The planner's history by occurrence: the nth appearance of an exercise in a workout reads the
/// nth appearance of it in each past session, and the first reads what it always did.
@MainActor
struct ProgressionPlannerTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func exercise(_ id: String, templateId: String, index: Int, weightKg: Double) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: id, authorId: "author-1", templateId: templateId, name: templateId,
            trackingMode: .weightReps, index: index,
            sets: [WorkoutSetModel(
                id: "\(id)-1", authorId: "author-1", index: 1, reps: 8, weightKg: weightKg,
                isWarmup: false, completedAt: start, dateCreated: start
            )]
        )
    }

    private func session(_ id: String, _ exercises: [WorkoutExerciseModel]) -> WorkoutSessionModel {
        WorkoutSessionModel(id: id, authorId: "author-1", name: "Push", dateCreated: start, endedAt: start, exercises: exercises)
    }

    /// Newest first: bench twice, then bench once.
    private var sessions: [WorkoutSessionModel] {
        [
            session("newest", [
                exercise("n-heavy", templateId: "bench", index: 1, weightKg: 100),
                exercise("n-row", templateId: "row", index: 2, weightKg: 50),
                exercise("n-backoff", templateId: "bench", index: 3, weightKg: 60)
            ]),
            session("older", [exercise("o-heavy", templateId: "bench", index: 1, weightKg: 97.5)])
        ]
    }

    @Test("Test The First Occurrence Reads Every Session As Before")
    func testTheFirstOccurrenceReadsEverySessionAsBefore() {
        let history = ProgressionPlanner.history(forTemplateId: "bench", in: sessions)

        #expect(history.map { $0.workingSets.map(\.weightKg) } == [[100], [97.5]])
    }

    /// The older session did the bench once, so it is no history for the back-off.
    @Test("Test The Second Occurrence Reads Only The Second Appearances")
    func testTheSecondOccurrenceReadsOnlyTheSecondAppearances() {
        let history = ProgressionPlanner.history(forTemplateId: "bench", occurrence: 1, in: sessions)

        #expect(history.map { $0.workingSets.map(\.weightKg) } == [[60]])
    }

    @Test("Test A Template Context Carries Its Occurrence Into Its Key")
    func testATemplateContextCarriesItsOccurrenceIntoItsKey() throws {
        let bench = try #require(ExerciseModel.mocks.first)
        let template = WorkoutTemplateExercise(exercise: bench, setRestTimers: false)

        let first = ProgressionPlanner.ExerciseContext(templateExercise: template, preferredWeightUnit: nil)
        let second = ProgressionPlanner.ExerciseContext(templateExercise: template, preferredWeightUnit: nil, occurrence: 1)

        #expect(first.historyKey == "\(bench.id)#0")
        #expect(second.historyKey == "\(bench.id)#1")
    }

    /// A session built from a template listing the bench twice fills each from its own suggestion.
    @Test("Test The Prefill Reads Each Appearances Own Suggestion")
    func testThePrefillReadsEachAppearancesOwnSuggestion() throws {
        let bench = try #require(ExerciseModel.mocks.first { WorkoutSessionModel.trackingMode(for: $0) == .weightReps && !WorkoutSessionModel.isPerSide($0) })
        let template = WorkoutTemplateModel(
            id: "template-1", authorId: "author-1", name: "Push",
            exercises: [
                WorkoutTemplateExercise(exercise: bench, setRestTimers: false),
                WorkoutTemplateExercise(exercise: bench, setRestTimers: false)
            ]
        )
        let suggestions: [String: ProgressionSuggestion] = [
            "\(bench.id)#0": ProgressionSuggestion(rationale: .progressWeight, sets: [SuggestedSet(weightKg: 100, reps: 6)]),
            "\(bench.id)#1": ProgressionSuggestion(rationale: .hold, sets: [SuggestedSet(weightKg: 60, reps: 20)])
        ]

        let built = WorkoutSessionModel(authorId: "author-1", template: template, prefill: .suggestions(suggestions))

        let working = built.exercises.map { $0.sets.filter { !$0.isWarmup }.first?.reps }
        #expect(working == [6, 20])
    }
}
