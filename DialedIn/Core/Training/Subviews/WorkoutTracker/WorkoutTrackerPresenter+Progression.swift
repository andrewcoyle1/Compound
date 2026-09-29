//
//  WorkoutTrackerPresenter+Progression.swift
//  DialedIn
//
//  Smart progression on the live screen: the one-line hint under each exercise, and the
//  set-to-set re-suggestion behind `smartProgressionApplyInSession`.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    // MARK: - Session start

    /// Loads the suggestions for this session so the screen can explain itself. The sets were
    /// already filled in when the session was built; this is the reasoning behind them.
    func loadProgressionSuggestions() {
        Task {
            progressionSuggestions = await interactor.progressionSuggestions(
                for: workoutSession,
                gymProfile: gymProfile ?? interactor.favouriteGymProfile
            )
        }
    }

    /// What was filled in for the user, before they touched anything.
    ///
    /// Live adjustment rewrites a set only when it still holds these values — a set the user has
    /// edited is theirs, and the hint speaks for the engine instead.
    func captureProgressionBaseline() {
        for exercise in workoutSession.exercises {
            for set in exercise.sets where !set.isWarmup {
                progressionBaseline[set.id] = SuggestedSet(weightKg: set.weightKg, reps: set.reps)
            }
        }
    }

    /// The line the exercise header shows, or `nil` when there is nothing to say.
    func progressionHint(for exerciseId: String) -> String? {
        guard let exercise = workoutSession.exercises.first(where: { $0.id == exerciseId }),
              let rationale = progressionSuggestions[exercise.templateId]?.rationale,
              rationale != .noHistory else { return nil }

        let hint = rationale.hint
        guard !hint.isEmpty else { return nil }
        return String(localized: "Smart Progression: \(String(describing: hint.prefix(1).lowercased()))\(String(describing: hint.dropFirst()))")
    }

    // MARK: - Live adjustment

    /// Re-suggests the sets of an exercise that are still to come, from the one just logged.
    ///
    /// Off by default: this is `smartProgressionApplyInSession`, and with the toggle off nothing
    /// here runs at all.
    func applyLiveProgression(after completed: WorkoutSetModel, in exerciseId: String) {
        guard interactor.workoutSettings.smartProgressionApplyInSession,
              let exerciseIndex = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId })
        else { return }

        let exercise = workoutSession.exercises[exerciseIndex]
        guard exercise.trackingMode == .weightReps else { return }

        let workingSets = exercise.sets.filter { !$0.isWarmup }
        guard let position = workingSets.firstIndex(where: { $0.id == completed.id }) else { return }

        let perSide = workingSets.contains { $0.side != nil }
        let remaining = workingSets[(position + 1)...].filter { $0.completedAt == nil }
        guard !remaining.isEmpty else { return }

        let rule = ProgressionPlanner.roundingRule(
            for: progressionContext(for: exercise),
            gymProfile: gymProfile ?? interactor.favouriteGymProfile
        )
        let adjusted = ProgressionEngine().adjustRemaining(
            completed: completed,
            target: setTarget(of: exercise, forWorkingSetAt: perSide ? position / 2 : position),
            remaining: Array(remaining),
            mode: exercise.trackingMode,
            rounding: rule.progressionRounding
        )

        applyAdjustments(adjusted, to: Array(remaining), in: exerciseIndex)
    }

    /// Writes the adjustments back, skipping every set the user has since edited.
    private func applyAdjustments(_ adjusted: [SuggestedSet?], to remaining: [WorkoutSetModel], in exerciseIndex: Int) {
        var exercises = workoutSession.exercises
        var changed = 0

        for (offset, suggestion) in adjusted.enumerated() {
            guard let suggestion, offset < remaining.count else { continue }
            let set = remaining[offset]
            guard let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == set.id }) else { continue }

            // Only what the engine itself put there may be rewritten.
            let baseline = progressionBaseline[set.id]
            guard baseline?.weightKg == set.weightKg, baseline?.reps == set.reps else { continue }

            exercises[exerciseIndex].sets[setIndex].weightKg = suggestion.weightKg ?? set.weightKg
            exercises[exerciseIndex].sets[setIndex].reps = suggestion.reps ?? set.reps
            progressionBaseline[set.id] = SuggestedSet(
                weightKg: exercises[exerciseIndex].sets[setIndex].weightKg,
                reps: exercises[exerciseIndex].sets[setIndex].reps
            )
            changed += 1
        }

        guard changed > 0 else { return }
        interactor.trackEvent(event: Event.progressionAdjusted(
            exerciseId: exercises[exerciseIndex].id,
            setsChanged: changed
        ))
        workoutSession.updateExercises(exercises)
    }

    private func progressionContext(for exercise: WorkoutExerciseModel) -> ProgressionPlanner.ExerciseContext {
        ProgressionPlanner.ExerciseContext(
            sessionExercise: exercise,
            exercise: interactor.allExercises.first(where: { $0.id == exercise.templateId }),
            preferredWeightUnit: exerciseUnitPreferences[exercise.templateId]?.weightUnit
        )
    }

    /// The target for one working set, with the last target standing in for any set past the end
    /// of the list — the same rule the engine uses.
    private func setTarget(of exercise: WorkoutExerciseModel, forWorkingSetAt index: Int) -> SetTarget? {
        guard !exercise.setTargets.isEmpty else { return nil }
        return index < exercise.setTargets.count ? exercise.setTargets[index] : exercise.setTargets.last
    }
}
