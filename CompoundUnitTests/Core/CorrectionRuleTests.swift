//
//  CorrectionRuleTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// `ActiveWorkout+Correction`: which set the correction row follows, what it says, and how its
/// reps-in-reserve chips map onto the RPE a set stores.
@MainActor
struct CorrectionRuleTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(_ id: String, reps: Int? = 8, weightKg: Double? = 100, side: SetSide? = nil, warmup: Bool = false, doneAt minutes: Double? = nil) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "u", index: 1, reps: reps, weightKg: weightKg, side: side,
            isWarmup: warmup, completedAt: minutes.map { start.addingTimeInterval($0 * 60) }, dateCreated: start
        )
    }

    private func exercise(_ id: String, _ sets: [WorkoutSetModel], mode: TrackingMode = .weightReps) -> WorkoutExerciseModel {
        WorkoutExerciseModel(id: id, authorId: "u", templateId: "t-\(id)", name: "Bench Press", trackingMode: mode, index: 1, sets: sets)
    }

    // MARK: - Which set

    @Test func theLatestLoggedWorkingSetOfTheCardsExerciseGetsTheRow() {
        let bench = exercise("e1", [set("s1", doneAt: 1), set("s2", doneAt: 3), set("s3")])
        let latest = ActiveWorkout.latestCompletedSet(in: [bench])
        #expect(ActiveWorkout.correctionTarget(in: bench, latestLogged: latest) == "s2")
    }

    /// The next log moves it, rest or not: the row is for the set just done.
    @Test func theNextLogMovesTheRow() {
        var bench = exercise("e1", [set("s1", doneAt: 1), set("s2", doneAt: 3), set("s3")])
        bench.sets[2].completedAt = start.addingTimeInterval(600)
        #expect(ActiveWorkout.correctionTarget(in: bench, latestLogged: ActiveWorkout.latestCompletedSet(in: [bench])) == "s3")
    }

    /// Logged on another card, as a superset partner's set is: this card has nothing to correct.
    @Test func aSetLoggedOnAnotherExerciseLeavesThisCardWithoutARow() {
        let bench = exercise("e1", [set("e1-s1", doneAt: 1), set("e1-s2")])
        let row = exercise("e2", [set("e2-s1", doneAt: 2)])
        let latest = ActiveWorkout.latestCompletedSet(in: [bench, row])
        #expect(ActiveWorkout.correctionTarget(in: bench, latestLogged: latest) == nil)
        #expect(ActiveWorkout.correctionTarget(in: row, latestLogged: latest) == "e2-s1")
    }

    @Test func warmUpsAndNothingLoggedGetNoRow() {
        let bench = exercise("e1", [set("w1", warmup: true, doneAt: 1), set("s1")])
        #expect(ActiveWorkout.correctionTarget(in: bench, latestLogged: ActiveWorkout.latestCompletedSet(in: [bench])) == nil)
        #expect(ActiveWorkout.correctionTarget(in: bench, latestLogged: nil) == nil)
        #expect(ActiveWorkout.correctionTarget(in: bench, latestLogged: set("s1")) == nil)
    }

    // MARK: - Reps in reserve

    @Test(arguments: [(0, 10.0), (1, 9), (2, 8), (3, 7), (4, 6), (7, 6), (-1, 10)])
    func chipsMapToRPE(rir: Int, rpe: Double) {
        #expect(ActiveWorkout.rirChip(rir) == rpe)
    }

    @Test(arguments: [(10.0 as Double?, 0 as Int?), (8, 2), (6, 4), (5, 4), (8.5, nil), (nil, nil)])
    func rpeShowsAsAChip(rpe: Double?, chip: Int?) {
        #expect(ActiveWorkout.rirChip(forRPE: rpe) == chip)
    }

    @Test func everyChipReadsBackAsItself() {
        for chip in ActiveWorkout.rirChips {
            #expect(ActiveWorkout.rirChip(forRPE: ActiveWorkout.rirChip(chip)) == chip)
        }
    }

    // MARK: - What it says

    @Test func theRowReadsTheSetAndItsFigures() {
        let bench = exercise("e1", [set("s1", doneAt: 1), set("s2", doneAt: 2)])
        #expect(ActiveWorkout.correctionTitle(for: bench.sets[1], in: bench, unit: .kilograms, distanceUnit: .meters) == "Set 2 · 100 kg × 8")
    }

    @Test func voiceOverHearsTheUnitsInWords() {
        let english = Locale(identifier: "en_US")
        let bench = exercise("e1", [set("s1", doneAt: 1), set("s2", weightKg: 102.5, doneAt: 2)])
        #expect(ActiveWorkout.correctionSpokenLabel(for: bench.sets[1], in: bench, unit: .kilograms, distanceUnit: .meters, locale: english)
                == "Set 2 logged, 102.5 kilograms, 8 reps")
        let pullUps = exercise("e2", [set("s1", reps: 12, weightKg: nil, doneAt: 1)], mode: .repsOnly)
        #expect(ActiveWorkout.correctionSpokenLabel(for: pullUps.sets[0], in: pullUps, unit: .kilograms, distanceUnit: .meters, locale: english)
                == "Set 1 logged, 12 reps")
    }

    @Test func aSideCarriesItsInitial() {
        let curls = exercise("e1", [set("l1", side: .left, doneAt: 1), set("r1", side: .right)])
        #expect(ActiveWorkout.setNumberLabel(for: curls.sets[0], in: curls) == "1L")
    }

    @Test func spokenWeightIsInTheExercisesUnit() {
        let english = Locale(identifier: "en_US")
        #expect(ActiveWorkout.spokenWeight(kg: 102.5, unit: .kilograms, locale: english) == "102.5 kilograms")
        #expect(ActiveWorkout.spokenWeight(kg: UnitConversion.convertWeightToKg(225, from: ExerciseWeightUnit.pounds), unit: .pounds, locale: english) == "225 pounds")
    }
}
