//
//  CoreInteractor+Progression.swift
//  Compound
//
//  Smart progression's two entry points: the prefill a session is built with, and the
//  suggestions the tracker screen keeps so it can explain itself and adjust live.
//

import Foundation

extension CoreInteractor {

    /// How the working sets of a session started from `template` should be filled in.
    ///
    /// `.smartProgression` runs the engine per exercise; an exercise with no history yields
    /// `.noHistory` and falls back to the previous session's values, which is what the user would
    /// have seen anyway.
    func sessionPrefill(
        for template: WorkoutTemplateModel,
        authorId: String,
        mesocycleId: String?,
        unitPreferences: [String: ExerciseUnitPreference]
    ) async -> SessionPrefill {
        switch workoutSettings.smartProgressionInitialLogFill {
        case .previousValues:
            return .previousValues
        case .empty:
            return .empty
        case .smartProgression:
            let contexts = template.exercises.enumerated().map { index, templateExercise in
                ProgressionPlanner.ExerciseContext(
                    templateExercise: templateExercise,
                    preferredWeightUnit: unitPreferences[templateExercise.exercise.id]?.weightUnit,
                    occurrence: template.exercises[..<index].filter { $0.exercise.id == templateExercise.exercise.id }.count
                )
            }
            return .suggestions(
                await suggestions(
                    for: contexts,
                    workoutTemplateId: template.id,
                    authorId: authorId,
                    mesocycleId: mesocycleId,
                    gymProfile: workoutGymProfile
                )
            )
        }
    }

    /// The suggestions for a session already under way, so the tracker can show why a set reads
    /// the way it does and re-suggest the sets still to come. Keyed by `ActiveWorkout.historyKey`.
    func progressionSuggestions(
        for session: WorkoutSessionModel,
        gymProfile: GymProfileModel?
    ) async -> [String: ProgressionSuggestion] {
        guard let authorId = currentUser?.userId else { return [:] }

        let contexts = session.exercises.map { exercise in
            ProgressionPlanner.ExerciseContext(
                sessionExercise: exercise,
                exercise: allExercises.first(where: { $0.id == exercise.templateId }),
                preferredWeightUnit: getPreference(templateId: exercise.templateId).weightUnit,
                occurrence: session.occurrence(of: exercise)
            )
        }

        return await suggestions(
            for: contexts,
            workoutTemplateId: session.workoutTemplateId,
            authorId: authorId,
            mesocycleId: session.mesocycleId,
            gymProfile: gymProfile ?? workoutGymProfile
        )
    }

    /// What a deload's lighter weights round to for `exercise` (`WorkoutStartInteractor`): the
    /// equipment chosen for it in the workout's gym, in the exercise's unit, as the keyboard steps.
    func deloadRounding(for exercise: WorkoutExerciseModel) -> (Double) -> Double {
        let context = ProgressionPlanner.ExerciseContext(
            sessionExercise: exercise,
            exercise: allExercises.first(where: { $0.id == exercise.templateId }),
            preferredWeightUnit: getPreference(templateId: exercise.templateId).weightUnit
        )
        let rule = WeightRoundingRule(
            exercise: context.exercise,
            gymProfile: workoutGymProfile,
            preferredWeightUnit: context.preferredWeightUnit,
            resistanceEquipment: context.resistanceEquipment
        )
        return rule.round
    }

    /// History is resolved per exercise, because `previousWorkoutReference` is: an exercise this
    /// workout has never held falls back to wherever the user last performed it, and that fallback
    /// is decided one exercise at a time. `ProgressionPlanner.suggestions` takes one session list
    /// for a batch of contexts, so each context is asked for on its own and the answers merged.
    private func suggestions(
        for contexts: [ProgressionPlanner.ExerciseContext],
        workoutTemplateId: String?,
        authorId: String,
        mesocycleId: String?,
        gymProfile: GymProfileModel?
    ) async -> [String: ProgressionSuggestion] {
        var result: [String: ProgressionSuggestion] = [:]

        for context in contexts {
            let history = await previousSessions(
                forExerciseTemplateId: context.templateId,
                workoutTemplateId: workoutTemplateId,
                authorId: authorId,
                mesocycleId: mesocycleId,
                limit: 3
            )
            let suggestion = ProgressionPlanner.suggestions(
                for: [context],
                history: history,
                adjustmentMode: workoutSettings.smartProgressionAdjustmentMode,
                gymProfile: gymProfile,
                amrap: workoutSettings.amrapProgression
            )
            result.merge(suggestion) { _, latest in latest }
        }

        return result
    }
}
