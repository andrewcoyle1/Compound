//
//  ProgressionPlanner.swift
//  Compound
//
//  The glue between the app's data and the pure `ProgressionEngine`: it gathers an exercise's
//  history out of past sessions, resolves what its weight is allowed to be, and hands the engine
//  an input it can reason about without knowing a manager exists.
//

import Foundation

@MainActor
struct ProgressionPlanner {

    /// One exercise, described the way the engine needs it. Built either from a template (before
    /// a session exists) or from a session's own exercise (once it does).
    struct ExerciseContext {
        let templateId: String
        let trackingMode: TrackingMode
        let setTargets: [SetTarget]
        /// The library exercise, for the equipment it is performed on. Absent, the weight is
        /// only rounded to the user's unit.
        let exercise: ExerciseModel?
        let preferredWeightUnit: ExerciseWeightUnit?
        /// The equipment chosen for this session, when the exercise has a session to read it from.
        let resistanceEquipment: [EquipmentRef]?

        init(
            templateId: String,
            trackingMode: TrackingMode,
            setTargets: [SetTarget],
            exercise: ExerciseModel?,
            preferredWeightUnit: ExerciseWeightUnit?,
            resistanceEquipment: [EquipmentRef]? = nil
        ) {
            self.templateId = templateId
            self.trackingMode = trackingMode
            self.setTargets = setTargets
            self.exercise = exercise
            self.preferredWeightUnit = preferredWeightUnit
            self.resistanceEquipment = resistanceEquipment
        }

        init(templateExercise: WorkoutTemplateExercise, preferredWeightUnit: ExerciseWeightUnit?) {
            self.init(
                templateId: templateExercise.exercise.id,
                trackingMode: WorkoutSessionModel.trackingMode(for: templateExercise.exercise),
                setTargets: templateExercise.setTargets,
                exercise: templateExercise.exercise,
                preferredWeightUnit: preferredWeightUnit
            )
        }

        init(
            sessionExercise: WorkoutExerciseModel,
            exercise: ExerciseModel?,
            preferredWeightUnit: ExerciseWeightUnit?
        ) {
            self.init(
                templateId: sessionExercise.templateId,
                trackingMode: sessionExercise.trackingMode,
                setTargets: sessionExercise.setTargets,
                exercise: exercise,
                preferredWeightUnit: preferredWeightUnit,
                resistanceEquipment: sessionExercise.chosenVariationId.flatMap { chosen in
                    sessionExercise.equipmentVariations.first { $0.id == chosen }?.resistanceEquipment
                }
            )
        }
    }

    /// A suggestion per exercise, keyed by `templateId`. Exercises with nothing to progress from
    /// still get an entry, carrying `.noHistory`, so a caller can tell "no history" from
    /// "not asked about".
    static func suggestions(
        for contexts: [ExerciseContext],
        history sessions: [WorkoutSessionModel],
        adjustmentMode: ProgressionAdjustmentMode,
        gymProfile: GymProfileModel?
    ) -> [String: ProgressionSuggestion] {
        let engine = ProgressionEngine()
        var result: [String: ProgressionSuggestion] = [:]

        for context in contexts {
            let rule = roundingRule(for: context, gymProfile: gymProfile)
            let input = ProgressionInput(
                trackingMode: context.trackingMode,
                setTargets: context.setTargets,
                history: history(forTemplateId: context.templateId, in: sessions),
                adjustmentMode: adjustmentMode,
                roundWeight: rule.round,
                minimumIncrementKg: rule.minimumIncrementKg
            )
            result[context.templateId] = engine.suggest(input)
        }

        return result
    }

    static func roundingRule(for context: ExerciseContext, gymProfile: GymProfileModel?) -> WeightRoundingRule {
        WeightRoundingRule(
            exercise: context.exercise,
            gymProfile: gymProfile,
            preferredWeightUnit: context.preferredWeightUnit,
            resistanceEquipment: context.resistanceEquipment
        )
    }

    /// One exercise's history: its completed working sets out of each session that has any, most
    /// recent first, at most three deep.
    ///
    /// `sessions` is expected most recent first. A session where the exercise was not reached is
    /// dropped rather than counted as a miss — it says nothing about how the exercise went.
    static func history(
        forTemplateId templateId: String,
        in sessions: [WorkoutSessionModel],
        limit: Int = 3
    ) -> [ProgressionHistorySession] {
        var history: [ProgressionHistorySession] = []

        for session in sessions {
            guard let exercise = session.exercises.first(where: { $0.templateId == templateId }) else { continue }
            let workingSets = completedWorkingSets(of: exercise)
            guard !workingSets.isEmpty else { continue }
            history.append(ProgressionHistorySession(workingSets: workingSets))
            if history.count == limit { break }
        }

        return history
    }

    /// The sets that count as one session's attempt at an exercise. The two rows of a per-side
    /// set are one set, so only the left one is read — otherwise three sets a side would look
    /// like six and every rep count would be read twice. A sub-set (a drop or mini-set) is part of
    /// its parent's set, and the parent's figures are the ones to progress from.
    private static func completedWorkingSets(of exercise: WorkoutExerciseModel) -> [WorkoutSetModel] {
        exercise.sets
            .filter { !$0.isWarmup && $0.completedAt != nil && !$0.isSubSet }
            .filter { $0.side != .right }
    }
}
