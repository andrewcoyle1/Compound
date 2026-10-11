//
//  ProgressionAuditTests.swift
//  CompoundUnitTests
//
//  The progression fixes from the 10 Oct 2026 audit
//  (docs/reviews/2026-10-10-equipment-variation-progression-audit.md): each case here stalled,
//  went backwards or suggested something the gym could not load.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct ProgressionAuditTests {

    private let engine = ProgressionEngine()
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func sets(_ values: [(kg: Double?, reps: Int?)], rpe: Double? = nil, kind: SetKind = .standard) -> [WorkoutSetModel] {
        values.enumerated().map { index, value in
            WorkoutSetModel(
                id: "set-\(index + 1)", authorId: "a", index: index + 1, reps: value.reps, weightKg: value.kg, rpe: rpe,
                kind: kind, isWarmup: false, completedAt: start, dateCreated: start
            )
        }
    }

    private func input(
        mode: TrackingMode = .weightReps,
        targets: [SetTarget],
        history: [[WorkoutSetModel]],
        round: @escaping (Double) -> Double = { ($0 * 2).rounded() / 2 },
        increment: Double = 2.5
    ) -> ProgressionInput {
        ProgressionInput(
            trackingMode: mode, setTargets: targets, history: history.map { ProgressionHistorySession(workingSets: $0) },
            adjustmentMode: .weightFirst, roundWeight: round, minimumIncrementKg: increment
        )
    }

    private func range(_ min: Int?, _ max: Int?, count: Int = 3, type: SetTargetSetType = .standard, rir: Int? = nil) -> [SetTarget] {
        (1...count).map { SetTarget(setNumber: $0, minReps: min, maxReps: max, rirTarget: rir, setType: type) }
    }

    // MARK: - Nothing heavier

    /// A rack with nothing between 10 and 30: at 30 × 12 there is nowhere heavier to go, so a rep
    /// more, not 30 × 8.
    @Test func atTheTopOfTheRackARepIsAdded() {
        let rack: (Double) -> Double = { weight in [10.0, 30].min { abs($0 - weight) < abs($1 - weight) } ?? weight }
        // Twice at the top, as a set without RPE needs before weight goes on.
        let top = sets([(30, 12), (30, 12), (30, 12)])
        let suggestion = engine.suggest(input(targets: range(8, 12), history: [top, top], round: rack, increment: 20))
        #expect(suggestion.sets.allSatisfy { $0.weightKg == 30 && $0.reps == 13 })
        #expect(suggestion.rationale == .addReps)
    }

    /// A weight/reps set logged with no weight (dips at body weight) does a rep more.
    @Test func noWeightLoggedAddsARep() {
        let top = sets([(nil, 12), (nil, 12), (nil, 12)])
        let suggestion = engine.suggest(input(targets: range(8, 12), history: [top, top]))
        #expect(suggestion.sets.allSatisfy { $0.weightKg == nil && $0.reps == 13 })
    }

    // MARK: - Ranges

    /// No range: 8–12, so 60 × 12 earns weight rather than 60 × 13, 14, 15…
    @Test func noRangeUsesTheDefault() {
        let suggestion = engine.suggest(input(targets: range(nil, nil), history: [sets([(60, 12), (60, 12), (60, 12)])], increment: 2.5))
        // Weight-first with RPE missing needs two sessions at the top; with both, weight goes on.
        let twice = engine.suggest(input(
            targets: range(nil, nil),
            history: [sets([(60, 12), (60, 12), (60, 12)]), sets([(60, 12), (60, 12), (60, 12)])]
        ))
        #expect(suggestion.sets.first?.reps == 12)
        #expect(twice.rationale == .progressWeight)
        #expect(twice.sets.first?.weightKg ?? 0 > 60)
        #expect(twice.sets.first?.reps == 8)
    }

    /// Five reps with no range set is not a miss: nobody prescribed eight.
    @Test func belowTheDefaultRangeIsNotAMiss() {
        let suggestion = engine.suggest(input(targets: range(nil, nil), history: [sets([(40, 5), (40, 5), (40, 5)])]))
        #expect(suggestion.rationale == .addReps)
        #expect(suggestion.sets.first?.reps == 6)
    }

    /// One end alone reaches four reps to the other.
    @Test func oneEndOfARangeIsWidened() {
        let suggestion = engine.suggest(input(targets: range(6, nil), history: [
            sets([(80, 10), (80, 10), (80, 10)]), sets([(80, 10), (80, 10), (80, 10)])
        ]))
        #expect(suggestion.rationale == .progressWeight)
        #expect(suggestion.sets.first?.reps == 6)
    }

    /// Pull-ups past the top of 8–12 keep climbing: 13, then 14, never 13 forever.
    @Test func repsOnlyKeepsClimbing() {
        let thirteen = sets([(nil, 13), (nil, 13), (nil, 13)])
        let suggestion = engine.suggest(input(mode: .repsOnly, targets: range(8, 12), history: [thirteen, thirteen]))
        #expect(suggestion.sets.allSatisfy { $0.reps == 14 })
    }

    // MARK: - Judged sets

    /// An AMRAP set at RPE 10 aims for none in reserve, so it does not hold the weight back.
    @Test func anAMRAPSetAtFailureIsWithinItsTarget() {
        let targets = range(5, 5, count: 2) + [SetTarget(setNumber: 3, minReps: 5, maxReps: 5, setType: .amrap)]
        let history = [
            sets([(100, 5), (100, 5)], rpe: 8) + sets([(100, 9)], rpe: 10).map { set in
                var set = set
                set.index = 3
                return set
            }
        ]
        let compound = ProgressionInput(
            trackingMode: .weightReps, setTargets: targets, history: history.map { ProgressionHistorySession(workingSets: $0) },
            adjustmentMode: .weightFirst, roundWeight: { ($0 * 2).rounded() / 2 }, minimumIncrementKg: 2.5, exerciseType: .compoundLower
        )
        #expect(engine.suggest(compound).rationale == .progressWeight)
    }

    // MARK: - Timed and distance

    @Test func shortHoldsAndDistancesGrow() {
        let hold = sets([(nil, nil)]).map { set in
            var set = set
            set.durationSec = 10
            set.distanceMeters = 20
            return set
        }
        let timed = engine.suggest(input(mode: .timeOnly, targets: range(nil, nil, count: 1), history: [hold]))
        #expect(timed.sets.first?.durationSec == 15)
        let carried = engine.suggest(input(mode: .distanceTime, targets: range(nil, nil, count: 1), history: [hold]))
        #expect(carried.sets.first?.distanceMeters == 21)
    }

    /// Fewer sets logged than planned is not a finished session: hold.
    @Test func fewerSetsThanPlannedHolds() {
        let one = sets([(nil, nil)]).map { set in
            var set = set
            set.durationSec = 60
            return set
        }
        let suggestion = engine.suggest(input(mode: .timeOnly, targets: range(nil, nil, count: 3), history: [one]))
        #expect(suggestion.rationale == .hold)
    }

    // MARK: - AMRAP

    /// "Beaten twice" counts only sessions at the same weight.
    @Test func anAMRAPTargetRisesOnlyAfterTwoSessionsAtTheWeight() {
        var last = sets([(102.5, 9)])[0]
        last.targetReps = 8
        let previous = sets([(100, 13)])[0]
        let next = AMRAPProgression(ceiling: 12).next(templateTarget: 8, last: last, previous: previous) { $0 + 2.5 }
        #expect(next.targetReps == 8)
        #expect(next.weightKg == 102.5)
    }

    // MARK: - Live adjustment

    /// A miss on an assisted exercise gives more help, not less.
    @Test func aLiveMissOnAssistanceAddsAssistance() {
        let completed = sets([(-30, 4)])[0]
        let adjusted = engine.adjustRemaining(
            completed: completed,
            target: SetTarget(setNumber: 1, minReps: 8, maxReps: 12),
            remaining: sets([(-30, nil)]),
            mode: .weightReps,
            rounding: ProgressionRounding(round: { ($0 * 2).rounded() / 2 }, minimumIncrementKg: 2.5)
        )
        let weight = adjusted.first??.weightKg ?? 0
        #expect(weight < -30)
    }

    // MARK: - Deload

    /// 15 kg on a 5 kg stack: 90% rounds back to 15, so one step lighter.
    @Test func aDeloadIsAlwaysLighter() {
        let fives: (Double) -> Double = { ($0 / 5).rounded() * 5 }
        #expect(MesocycleDeload.lighterWeight(15, round: fives) == 10)
        #expect(MesocycleDeload.lighterWeight(5, round: { max(($0 / 5).rounded() * 5, 5) }) == 5)
        #expect(MesocycleDeload.lighterWeight(-30, round: { ($0 * 2).rounded() / 2 }) == -33)
    }

    // MARK: - History

    private func session(id: String, variation: [EquipmentRef], weight: Double, isDeload: Bool = false) -> WorkoutSessionModel {
        var session = WorkoutSessionModel(
            id: id, authorId: "a", name: "W", dateCreated: start, endedAt: start,
            exercises: [WorkoutExerciseModel(
                id: "e-\(id)", authorId: "a", templateId: "squat", name: "Squat", trackingMode: .weightReps, index: 1,
                sets: sets([(weight, 8)]), chosenVariationId: "v",
                equipmentVariations: [EquipmentVariation(id: "v", resistanceEquipment: variation)]
            )]
        )
        session.isDeload = isDeload
        return session
    }

    /// Deload weeks and sessions on another kind of load are passed over.
    @Test func historySkipsDeloadsAndOtherLoads() {
        let bar = [EquipmentRef(kind: .loadableBar, id: "barbell")]
        let dumbbells = [EquipmentRef(kind: .freeWeight, id: "dumbbells")]
        let history = ProgressionPlanner.history(
            forTemplateId: "squat",
            in: [
                session(id: "deload", variation: bar, weight: 90, isDeload: true),
                session(id: "db", variation: dumbbells, weight: 30),
                session(id: "bar", variation: bar, weight: 100)
            ],
            loadedWith: bar
        )
        #expect(history.count == 1)
        #expect(history.first?.workingSets.first?.weightKg == 100)
    }
}
