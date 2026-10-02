//
//  ProgressionSuggestionDisplayTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// What the tracker's Auto column shows, and which suggestion each row of it belongs to.
///
/// The column used to compute its own number from the previous set's estimated 1RM, which could
/// disagree with the engine that had already filled the row in. Now it reads the engine's own
/// suggestion, so the two things worth pinning down are the mapping — a row to its suggested set —
/// and the label, which has to read the same way the Prev column does in every tracking mode.
struct ProgressionSuggestionDisplayTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Helpers

    private func set(
        id: String,
        index: Int,
        side: SetSide? = nil,
        isWarmup: Bool = false
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id,
            authorId: "author-1",
            index: index,
            side: side,
            isWarmup: isWarmup,
            dateCreated: start
        )
    }

    private func exercise(sets: [WorkoutSetModel], mode: TrackingMode = .weightReps) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "exercise-1",
            authorId: "author-1",
            templateId: "template-1",
            name: "Bench Press",
            trackingMode: mode,
            index: 1,
            sets: sets
        )
    }

    private func suggestion(_ sets: [SuggestedSet]) -> ProgressionSuggestion {
        ProgressionSuggestion(rationale: .progressWeight, sets: sets)
    }

    // MARK: - Labels

    @Test("Weight and reps read in kilograms")
    func weightRepsLabelInKilograms() {
        let label = SuggestedSet(weightKg: 60, reps: 8).label(
            trackingMode: .weightReps,
            weightUnit: .kilograms,
            distanceUnit: .meters
        )

        #expect(label == "60.0 × 8")
    }

    @Test("Weight and reps read in pounds, converted from the stored kilograms")
    func weightRepsLabelInPounds() {
        let label = SuggestedSet(weightKg: 100, reps: 5).label(
            trackingMode: .weightReps,
            weightUnit: .pounds,
            distanceUnit: .meters
        )

        #expect(label == "220.5 × 5")
    }

    @Test("Reps-only shows the rep count alone")
    func repsOnlyLabel() {
        let label = SuggestedSet(reps: 12).label(
            trackingMode: .repsOnly,
            weightUnit: .kilograms,
            distanceUnit: .meters
        )

        #expect(label == "12")
    }

    @Test("A timed set reads as minutes and seconds")
    func timeOnlyLabel() {
        let label = SuggestedSet(durationSec: 95).label(
            trackingMode: .timeOnly,
            weightUnit: .kilograms,
            distanceUnit: .meters
        )

        #expect(label == "1:35")
    }

    @Test("Distance and time read together")
    func distanceTimeLabel() {
        let label = SuggestedSet(durationSec: 600, distanceMeters: 400).label(
            trackingMode: .distanceTime,
            weightUnit: .kilograms,
            distanceUnit: .meters
        )

        #expect(label == "400 m 10:00")
    }

    @Test("A suggestion silent about the tracked metrics has no label")
    func missingMetricsHasNoLabel() {
        let weightOnly = SuggestedSet(weightKg: 60)

        #expect(weightOnly.label(trackingMode: .weightReps, weightUnit: .kilograms, distanceUnit: .meters) == nil)
        #expect(SuggestedSet.none.label(trackingMode: .repsOnly, weightUnit: .kilograms, distanceUnit: .meters) == nil)
    }

    // MARK: - Row to suggestion

    @Test("Each working set reads its own suggestion, in order")
    func mapsWorkingSetsInOrder() {
        let sets = [set(id: "s1", index: 1), set(id: "s2", index: 2), set(id: "s3", index: 3)]
        let model = exercise(sets: sets)
        let suggested = suggestion([
            SuggestedSet(weightKg: 60, reps: 8),
            SuggestedSet(weightKg: 62.5, reps: 8),
            SuggestedSet(weightKg: 65, reps: 6)
        ])

        let mapped = sets.map { suggested.suggestedSet(for: $0, in: model) }

        #expect(mapped.map { $0?.weightKg } == [60, 62.5, 65])
    }

    @Test("A left and a right share the one suggestion, because they are the one set")
    func pairSharesOneSuggestion() {
        let sets = [
            set(id: "s1L", index: 1, side: .left),
            set(id: "s1R", index: 1, side: .right),
            set(id: "s2L", index: 2, side: .left),
            set(id: "s2R", index: 2, side: .right)
        ]
        let model = exercise(sets: sets)
        let suggested = suggestion([
            SuggestedSet(weightKg: 20, reps: 10),
            SuggestedSet(weightKg: 22.5, reps: 10)
        ])

        let mapped = sets.map { suggested.suggestedSet(for: $0, in: model) }

        #expect(mapped[0] == mapped[1])
        #expect(mapped[2] == mapped[3])
        #expect(mapped.map { $0?.weightKg } == [20, 20, 22.5, 22.5])
    }

    @Test("A warm-up has no suggestion")
    func warmupHasNoSuggestion() {
        let warmup = set(id: "w1", index: 1, isWarmup: true)
        let working = set(id: "s1", index: 2)
        let model = exercise(sets: [warmup, working])
        let suggested = suggestion([SuggestedSet(weightKg: 60, reps: 8)])

        #expect(suggested.suggestedSet(for: warmup, in: model) == nil)
        #expect(suggested.suggestedSet(for: working, in: model)?.weightKg == 60)
    }

    @Test("A set past the end of the suggestion has none")
    func setPastTheEndHasNoSuggestion() {
        let sets = [set(id: "s1", index: 1), set(id: "s2", index: 2), set(id: "s3", index: 3)]
        let model = exercise(sets: sets)
        let suggested = suggestion([SuggestedSet(weightKg: 60, reps: 8)])

        #expect(suggested.suggestedSet(for: sets[1], in: model) == nil)
        #expect(suggested.suggestedSet(for: sets[2], in: model) == nil)
    }

    @Test("Nothing to say maps to nothing at all")
    func emptySuggestionsMapToNil() {
        let sets = [set(id: "s1", index: 1), set(id: "s2", index: 2)]
        let model = exercise(sets: sets)
        let suggested = ProgressionSuggestion.noHistory(setCount: 2)

        #expect(sets.allSatisfy { suggested.suggestedSet(for: $0, in: model) == nil })
    }
}
