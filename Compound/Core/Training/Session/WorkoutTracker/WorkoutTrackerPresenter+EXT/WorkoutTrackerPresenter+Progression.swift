//
//  WorkoutTrackerPresenter+Progression.swift
//  Compound
//
//  Smart progression on the live screen: the one-line hint under each exercise, the set-to-set
//  re-suggestion behind `smartProgressionApplyInSession`, and what the user did last time, which
//  both the hint and the Prev column read.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    // MARK: - Session start

    /// Loads the suggestions for this session so the screen can explain itself. The sets were
    /// already filled in when the session was built; this is the reasoning behind them.
    ///
    /// `exercises` narrows it to those added part-way through; the others keep what they have.
    /// Every appearance of a narrowed exercise is kept in, so each one's occurrence, and with it
    /// its key (`ActiveWorkout.historyKey`), is the one it has in the whole workout.
    func loadProgressionSuggestions(for exercises: [WorkoutExerciseModel]? = nil) {
        var session = workoutSession
        if let exercises {
            let templateIds = Set(exercises.map(\.templateId))
            session.updateExercises(workoutSession.exercises.filter { templateIds.contains($0.templateId) })
        }
        Task {
            var suggestions = await interactor.progressionSuggestions(for: session, gymProfile: interactor.workoutGymProfile)
            if workoutSession.isDeload == true { suggestions = deloaded(suggestions, in: session) }
            progressionSuggestions.merge(suggestions) { $1 }
        }
    }

    /// A deload week's suggestions at the deload's weight, so tapping one does not undo the
    /// deload the sets were built with (`WorkoutSessionModel.applyDeload`).
    private func deloaded(_ suggestions: [String: ProgressionSuggestion], in session: WorkoutSessionModel) -> [String: ProgressionSuggestion] {
        var result = suggestions
        for exercise in session.exercises {
            let key = ActiveWorkout.historyKey(templateId: exercise.templateId, occurrence: session.occurrence(of: exercise))
            guard let suggestion = result[key] else { continue }
            let rule = ProgressionPlanner.roundingRule(for: progressionContext(for: exercise), gymProfile: interactor.workoutGymProfile)
            result[key] = ProgressionSuggestion(rationale: suggestion.rationale, sets: suggestion.sets.map { set in
                SuggestedSet(
                    weightKg: set.weightKg.map { MesocycleDeload.lighterWeight($0, round: rule.round) },
                    reps: set.reps,
                    durationSec: set.durationSec,
                    distanceMeters: set.distanceMeters,
                    targetReps: set.targetReps
                )
            })
        }
        return result
    }

    /// What was filled in for the user, before they touched anything: in every exercise, or in
    /// `exercises` only when they were added part-way through.
    ///
    /// Live adjustment rewrites a set only when it still holds these values — a set the user has
    /// edited is theirs, and the hint speaks for the engine instead.
    func captureProgressionBaseline(of exercises: [WorkoutExerciseModel]? = nil) {
        var baseline = progressionBaseline
        for exercise in exercises ?? workoutSession.exercises {
            for set in exercise.sets where !set.isWarmup {
                baseline[set.id] = SuggestedSet(weightKg: set.weightKg, reps: set.reps)
            }
        }
        progressionBaseline = baseline
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

        // Sets of their own only: a drop, mini-set or piece is part of its set, planned lighter or
        // shorter on purpose, and a logged one says nothing about the next set.
        guard !completed.isSubSet else { return }
        let workingSets = exercise.sets.filter { !$0.isWarmup && !$0.isSubSet }
        guard let position = workingSets.firstIndex(where: { $0.id == completed.id }) else { return }

        // The set's number counts a left/right pair once, as targets do.
        let setNumber = { (index: Int) in max(workingSets[...index].filter { $0.side != .right }.count - 1, 0) }
        let target = setTarget(of: exercise, forWorkingSetAt: setNumber(position))
        // Only sets asked for the same as this one: a back-off after a top set has its own target.
        let remaining = workingSets.indices
            .filter { $0 > position && workingSets[$0].completedAt == nil }
            .filter { Self.sameAsk(setTarget(of: exercise, forWorkingSetAt: setNumber($0)), target) }
            .map { workingSets[$0] }
        guard !remaining.isEmpty else { return }

        let context = progressionContext(for: exercise)
        let rule = ProgressionPlanner.roundingRule(for: context, gymProfile: interactor.workoutGymProfile)
        let adjusted = ProgressionEngine().adjustRemaining(
            completed: completed,
            target: target,
            remaining: Array(remaining),
            mode: exercise.trackingMode,
            rounding: rule.progressionRounding,
            exerciseType: context.exercise?.type
        )

        applyAdjustments(adjusted, to: Array(remaining), in: exerciseIndex)
    }

    /// Writes the adjustments back, skipping every set the user has since edited.
    private func applyAdjustments(_ adjusted: [SuggestedSet?], to remaining: [WorkoutSetModel], in exerciseIndex: Int) {
        var exercises = workoutSession.exercises
        var baseline = progressionBaseline
        var changed = 0

        for (offset, suggestion) in adjusted.enumerated() {
            guard let suggestion, offset < remaining.count else { continue }
            let set = remaining[offset]
            guard let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == set.id }) else { continue }

            // Only what the engine itself put there may be rewritten.
            guard baseline[set.id]?.weightKg == set.weightKg, baseline[set.id]?.reps == set.reps else { continue }

            exercises[exerciseIndex].sets[setIndex].weightKg = suggestion.weightKg ?? set.weightKg
            exercises[exerciseIndex].sets[setIndex].reps = suggestion.reps ?? set.reps
            baseline[set.id] = SuggestedSet(
                weightKg: exercises[exerciseIndex].sets[setIndex].weightKg,
                reps: exercises[exerciseIndex].sets[setIndex].reps
            )
            changed += 1
        }

        guard changed > 0 else { return }
        progressionBaseline = baseline
        interactor.trackEvent(event: Event.progressionAdjusted(
            exerciseId: exercises[exerciseIndex].id,
            setsChanged: changed
        ))
        workoutSession.updateExercises(exercises)
    }

    /// Two targets asking for the same set: the same kind, range and reps in reserve.
    private static func sameAsk(_ lhs: SetTarget?, _ rhs: SetTarget?) -> Bool {
        lhs?.setType == rhs?.setType && lhs?.minReps == rhs?.minReps
            && lhs?.maxReps == rhs?.maxReps && lhs?.rirTarget == rhs?.rirTarget
    }

    private func progressionContext(for exercise: WorkoutExerciseModel) -> ProgressionPlanner.ExerciseContext {
        ProgressionPlanner.ExerciseContext(
            sessionExercise: exercise,
            exercise: exercise.libraryModel(in: interactor.allExercises),
            preferredWeightUnit: exercise.weightUnit ?? interactor.getPreference(templateId: exercise.templateId).weightUnit
        )
    }

    /// The target for one working set, with the last target standing in for any set past the end
    /// of the list — the same rule the engine uses.
    private func setTarget(of exercise: WorkoutExerciseModel, forWorkingSetAt index: Int) -> SetTarget? {
        guard !exercise.setTargets.isEmpty else { return nil }
        return index < exercise.setTargets.count ? exercise.setTargets[index] : exercise.setTargets.last
    }

    // MARK: - Last time

    /// Loads what the user last did for every exercise on screen, honouring
    /// `previousWorkoutReference` through `interactor.previousSessions(...)` — the same resolution
    /// smart progression uses, so the "Prev" column and the "Auto" column can never disagree about
    /// what last time was.
    ///
    /// Resolved one exercise at a time because the fallback is per exercise: an exercise this
    /// template has never held still shows the last time it was performed anywhere. Kept by
    /// `ActiveWorkout.historyKey`, so an exercise the workout holds twice has a last time for each.
    func loadPreviousWorkoutSession() {
        loadPrevious(for: workoutSession.exercises)
    }

    /// The same, for some exercises only: those added part-way through, or moved onto other
    /// equipment. What is already loaded for the others is kept. The nth appearance of an exercise
    /// is matched to the nth appearance of it in the session found, on the same kind of load
    /// (`LoadKind`) and outside a deload week, as smart progression reads history: last time's
    /// dumbbell press is no guide to today's barbell.
    func loadPrevious(for exercises: [WorkoutExerciseModel]) {
        guard let authorId = interactor.currentUser?.userId else { return }

        let workoutTemplateId = workoutSession.workoutTemplateId
        let mesocycleId = workoutSession.mesocycleId
        let session = workoutSession
        let wanted = exercises.map {
            (templateId: $0.templateId, occurrence: session.occurrence(of: $0), refs: $0.activeVariation?.resistanceEquipment)
        }

        Task {
            var resolved: [String: WorkoutExerciseModel?] = [:]

            for exerciseTemplateId in Set(wanted.map(\.templateId)) {
                let sessions = await interactor.previousSessions(
                    forExerciseTemplateId: exerciseTemplateId,
                    workoutTemplateId: workoutTemplateId,
                    authorId: authorId,
                    mesocycleId: mesocycleId,
                    limit: 5
                )
                for entry in wanted where entry.templateId == exerciseTemplateId {
                    // The last time it was done, else the last time it was on the plan (for its note).
                    let candidates = sessions
                        .filter { $0.isDeload != true }
                        .compactMap { $0.exercise(templateId: exerciseTemplateId, occurrence: entry.occurrence) }
                        .filter { WorkoutSessionModel.isSameLoad($0.activeVariation?.resistanceEquipment, entry.refs) }
                    let match = candidates.first { !$0.loggedWorkingSets.isEmpty } ?? candidates.first
                    resolved[ActiveWorkout.historyKey(templateId: exerciseTemplateId, occurrence: entry.occurrence)] = .some(match)
                }
            }

            for (key, match) in resolved { previousExercises[key] = match }
        }
    }

    /// What `exercise` was last time, for its Prev column, summaries and note hint.
    func previousExercise(for exercise: WorkoutExerciseModel) -> WorkoutExerciseModel? {
        previousExercises[ActiveWorkout.historyKey(for: exercise, in: workoutSession)]
    }

    /// Smart progression's suggestion for `exercise`, by the same key as last time.
    func progressionSuggestion(for exercise: WorkoutExerciseModel) -> ProgressionSuggestion? {
        progressionSuggestions[ActiveWorkout.historyKey(for: exercise, in: workoutSession)]
    }
}
