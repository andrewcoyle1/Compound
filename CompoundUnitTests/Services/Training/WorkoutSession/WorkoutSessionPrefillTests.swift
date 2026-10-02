//
//  WorkoutSessionPrefillTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// What a session's working sets hold before the user has typed anything.
///
/// The three Initial Log Fill options all land here: the previous session's values (what the app
/// has always done), nothing at all, and smart progression's suggestions. The last one also has
/// to carry the warm-ups with it — a warm-up ramp built for last week's weight is the wrong ramp
/// for a heavier session.
@MainActor
struct WorkoutSessionPrefillTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func exerciseModel() -> ExerciseModel {
        ExerciseModel(
            id: "exercise-1",
            authorId: "author-1",
            name: "Bench Press",
            trackableMetrics: [.weight, .reps],
            type: .compoundUpper,
            laterality: .bilateral,
            muscleGroups: [.chest: .primary],
            isBodyweight: false,
            rangeOfMotion: 4,
            stability: 5,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    private func template() -> WorkoutTemplateModel {
        WorkoutTemplateModel(
            id: "template-1",
            authorId: "author-1",
            name: "Push Day",
            exercises: [
                WorkoutTemplateExercise(
                    id: "template-exercise-1",
                    exercise: exerciseModel(),
                    setTargets: (1...3).map { SetTarget(id: "target-\($0)", setNumber: $0, minReps: 8, maxReps: 12) },
                    setRestTimers: false
                )
            ]
        )
    }

    /// A finished session of three sets at 60 kg for ten.
    private func previousSession() -> WorkoutSessionModel {
        let sets = (1...3).map { index in
            WorkoutSetModel(
                id: "previous-set-\(index)",
                authorId: "author-1",
                index: index,
                reps: 10,
                weightKg: 60,
                isWarmup: false,
                completedAt: start,
                dateCreated: start
            )
        }

        return WorkoutSessionModel(
            id: "previous-session",
            authorId: "author-1",
            name: "Push Day",
            workoutTemplateId: "template-1",
            dateCreated: start,
            endedAt: start.addingTimeInterval(3600),
            exercises: [
                WorkoutExerciseModel(
                    id: "previous-exercise",
                    authorId: "author-1",
                    templateId: "exercise-1",
                    name: "Bench Press",
                    trackingMode: .weightReps,
                    index: 1,
                    sets: sets
                )
            ]
        )
    }

    private func workingSets(of session: WorkoutSessionModel) -> [WorkoutSetModel] {
        session.exercises.first?.sets.filter { !$0.isWarmup } ?? []
    }

    private func warmupSets(of session: WorkoutSessionModel) -> [WorkoutSetModel] {
        session.exercises.first?.sets.filter { $0.isWarmup } ?? []
    }

    /// The default, and what every caller got before there was a setting: last session's numbers,
    /// with no progression applied.
    @Test("Test Previous Values Are Carried Over By Default")
    func testPreviousValuesAreCarriedOverByDefault() {
        let session = WorkoutSessionModel(
            authorId: "author-1",
            template: template(),
            previousWorkoutSession: previousSession(),
            dateCreated: start
        )

        #expect(workingSets(of: session).map(\.weightKg) == [60, 60, 60])
        #expect(workingSets(of: session).map(\.reps) == [10, 10, 10])
    }

    /// "Leave empty" means empty even when there is a session to copy from. Somebody who wants to
    /// type every number wants to type every number.
    @Test("Test An Empty Prefill Leaves The Working Sets Blank")
    func testAnEmptyPrefillLeavesTheWorkingSetsBlank() {
        let session = WorkoutSessionModel(
            authorId: "author-1",
            template: template(),
            previousWorkoutSession: previousSession(),
            prefill: .empty,
            dateCreated: start
        )

        let sets = workingSets(of: session)
        #expect(sets.count == 3)
        let allBlank = sets.allSatisfy { $0.weightKg == nil && $0.reps == nil }
        #expect(allBlank)
    }

    /// The suggestion wins over the previous session, and the warm-ups follow it: three sets of
    /// warm-up for a hundred kilos rather than the two the old sixty earned.
    @Test("Test Suggestions Fill The Working Sets And The Warm-Ups Follow")
    func testSuggestionsFillTheWorkingSetsAndTheWarmUpsFollow() {
        let suggestion = ProgressionSuggestion(
            rationale: .progressWeight,
            sets: Array(repeating: SuggestedSet(weightKg: 100, reps: 8), count: 3)
        )

        let session = WorkoutSessionModel(
            authorId: "author-1",
            template: template(),
            previousWorkoutSession: previousSession(),
            prefill: .suggestions(["exercise-1": suggestion]),
            dateCreated: start
        )

        #expect(workingSets(of: session).map(\.weightKg) == [100, 100, 100])
        #expect(workingSets(of: session).map(\.reps) == [8, 8, 8])
        #expect(warmupSets(of: session).map(\.weightKg) == [50, 70, 90])
    }

    /// An exercise the engine had nothing to say about falls back to the previous session rather
    /// than starting blank — the user is no worse off than before the feature existed.
    @Test("Test An Exercise With No History Falls Back To The Previous Values")
    func testAnExerciseWithNoHistoryFallsBackToThePreviousValues() {
        let session = WorkoutSessionModel(
            authorId: "author-1",
            template: template(),
            previousWorkoutSession: previousSession(),
            prefill: .suggestions(["exercise-1": .noHistory(setCount: 3)]),
            dateCreated: start
        )

        #expect(workingSets(of: session).map(\.weightKg) == [60, 60, 60])
        #expect(workingSets(of: session).map(\.reps) == [10, 10, 10])
    }
}
