//
//  AssistedWeightTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// Assisted machines (an exercise tracked by `.weightPerSideAssistance`) store their assistance as
/// a negative weight: −30 kg is 30 kg of help. Only they may go below zero, nothing multiplies a
/// negative weight into volume or a one-rep max, and progression needs no special case, because
/// adding weight to −30 kg is less help.
@MainActor
struct AssistedWeightTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(weightKg: Double?, reps: Int? = 8, done: Bool = false, side: SetSide? = nil) -> WorkoutSetModel {
        WorkoutSetModel(
            id: UUID().uuidString, authorId: "u", index: 1, reps: reps, weightKg: weightKg,
            side: side, isWarmup: false, completedAt: done ? start : nil, dateCreated: start
        )
    }

    private func exercise(metrics: [TrackableExerciseMetric], isBodyweight: Bool = true) -> ExerciseModel {
        ExerciseModel(
            id: "assisted-pull-up", authorId: "u", name: "Assisted Pull-Up", trackableMetrics: metrics,
            type: .compoundUpper, laterality: .bilateral, muscleGroups: [.lats: .primary], isBodyweight: isBodyweight,
            equipmentVariations: [], rangeOfMotion: 4, stability: 4, bodyWeightContribution: 100, alternateNames: []
        )
    }

    // MARK: - What counts as assisted

    @Test func onlyTheAssistanceMetricMakesAnExerciseAssisted() {
        #expect(exercise(metrics: [.reps, .weightPerSideAssistance]).isAssisted)
        #expect(!exercise(metrics: [.reps, .weight], isBodyweight: false).isAssisted)
        #expect(!exercise(metrics: [.reps]).isAssisted)
    }

    /// A bodyweight exercise with no weight metric has no weight field at all; with assistance it
    /// keeps one, for the help the machine gives.
    @Test func aBodyweightExerciseShowsAWeightFieldOnlyForAssistance() {
        #expect(WorkoutSessionModel.trackingMode(for: exercise(metrics: [.reps])) == .repsOnly)
        #expect(WorkoutSessionModel.trackingMode(for: exercise(metrics: [.reps, .weightPerSideAssistance])) == .weightReps)
    }

    // MARK: - Validation

    @Test func aNegativeWeightLogsOnlyWhenAssisted() {
        let assisted = set(weightKg: -30)
        #expect(SetValidation.problem(with: assisted, trackingMode: .weightReps) == "Enter a weight of zero or more.")
        #expect(!SetValidation.canLog(assisted, trackingMode: .weightReps, isAssisted: false))
        #expect(SetValidation.canLog(assisted, trackingMode: .weightReps, isAssisted: true))
        // Assistance does not excuse missing reps.
        #expect(!SetValidation.canLog(set(weightKg: -30, reps: nil), trackingMode: .weightReps, isAssisted: true))
        // Nor does it refuse an ordinary weight.
        #expect(SetValidation.canLog(set(weightKg: 20), trackingMode: .weightReps, isAssisted: true))
    }

    /// The shared log rule (log button and Live Activity) passes assistance through.
    @Test func theLogRuleLogsANegativeWeightOnlyWhenAssisted() throws {
        let pending = set(weightKg: -30)
        let exercise = WorkoutExerciseModel(
            id: "e", authorId: "u", templateId: "assisted-pull-up", name: "Assisted Pull-Up", trackingMode: .weightReps,
            index: 0, sets: [pending]
        )
        let session = WorkoutSessionModel(id: "s", authorId: "u", name: "Pull", dateCreated: start, exercises: [exercise])
        let context = RestDurationRules.ExerciseContext(restOverrideSeconds: nil, exerciseTypeRawValue: nil)
        let settings = WorkoutSettings(authorId: "u")

        let refused = try #require(ActiveWorkout.log(setId: pending.id, in: session, settings: settings, context: context, now: start))
        #expect(refused.problem != nil)
        let logged = try #require(ActiveWorkout.log(setId: pending.id, in: session, settings: settings, context: context, isAssisted: true, now: start))
        #expect(logged.problem == nil)
        #expect(logged.session.exercises[0].sets[0].completedAt == start)
    }

    // MARK: - Stepping

    @Test func theStepperNeverGoesBelowZeroUnlessAssisted() {
        let plain = WeightStepper.fallback(.kilograms)
        #expect(plain.previous(before: 0) == 0)
        #expect(plain.previous(before: nil) == 0)
        #expect(plain.previous(before: 2.5) == 0)

        let assisted = plain.assisted(bodyweightOnly: false)
        #expect(assisted.isAssisted)
        #expect(assisted.previous(before: 0) == -2.5)
        #expect(assisted.previous(before: -30) == -32.5)
        #expect(assisted.next(after: -30) == -27.5)
        #expect(assisted.next(after: 0) == 2.5)
    }

    /// An empty field steps from zero, not from the deepest assistance there is.
    @Test func anEmptyAssistedFieldStepsFromZero() {
        let assisted = WeightStepper.fallback(.kilograms).assisted(bodyweightOnly: true)
        #expect(assisted.previous(before: nil) == -2.5)
        #expect(assisted.next(after: nil) == 0)
    }

    /// An exercise that cannot be loaded beyond bodyweight stops at zero: no help, no load.
    @Test func aBodyweightOnlyAssistedExerciseNeverGoesAboveZero() {
        let assisted = WeightStepper.fallback(.kilograms).assisted(bodyweightOnly: true)
        #expect(assisted.next(after: -2.5) == 0)
        #expect(assisted.next(after: 0) == 0)
    }

    @Test func aListOfWeightsIsMirroredBelowZero() {
        let rack = WeightStep(kind: .list([5, 10]), chip: nil, baseWeight: nil, plates: [])
        let assisted = rack.assisted(bodyweightOnly: true)
        #expect(assisted.kind == .list([-10, -5, 0]))
        #expect(assisted.previous(before: nil) == -5)
        #expect(assisted.next(after: -10) == -5)
    }

    @Test func bandsAreLeftAlone() {
        let bands = WeightStep(kind: .bands, chip: nil, baseWeight: nil, plates: [], bands: ["Light"])
        #expect(bands.assisted(bodyweightOnly: true) == bands)
    }

    // MARK: - Volume and one-rep max

    @Test func aNegativeWeightHasNoVolume() {
        #expect(set(weightKg: -30).volumeKg == nil)
        #expect(set(weightKg: -30, side: .both).volumeKg == nil)
        #expect(set(weightKg: 0).volumeKg == 0)
        #expect(set(weightKg: 20).volumeKg == 160)
    }

    @Test func theOneRepMaxSkipsNegativeWeights() {
        let assisted = WorkoutExerciseModel(
            id: "e", authorId: "u", templateId: "assisted-pull-up", name: "Assisted Pull-Up", trackingMode: .weightReps,
            index: 0, sets: [set(weightKg: -30, done: true), set(weightKg: -20, done: true)]
        )
        let session = WorkoutSessionModel(
            id: "s", authorId: "u", name: "Pull", dateCreated: start, endedAt: start, exercises: [assisted]
        )
        #expect(ExerciseOneRMAggregator.aggregate(sessions: [session])["assisted-pull-up"] == nil)
    }

    // MARK: - Progression

    /// Progression is unchanged: one 2.5 kg step up from −30 kg is −27.5 kg, less help.
    @Test func progressingAnAssistedSetTakesAssistanceAway() {
        let rounding = WeightRoundingRule(step: WeightStepper.fallback(.kilograms), unit: .kilograms, preferredUnit: .kilograms).progressionRounding
        let completed = set(weightKg: -30, reps: 14, done: true)
        let suggestions = ProgressionEngine().adjustRemaining(
            completed: completed,
            target: SetTarget(setNumber: 1, minReps: 8, maxReps: 12),
            remaining: [set(weightKg: -30), set(weightKg: -30)],
            mode: .weightReps,
            rounding: rounding
        )
        #expect(suggestions.allSatisfy { $0?.weightKg == -27.5 })
    }
}
