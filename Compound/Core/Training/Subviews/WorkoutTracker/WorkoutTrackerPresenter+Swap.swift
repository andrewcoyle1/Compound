//
//  WorkoutTrackerPresenter+Swap.swift
//  Compound
//
//  Swapping an exercise mid-workout. What was logged stays with the exercise it was done on, and
//  the replacement takes the sets still to do.
//

import Foundation

extension WorkoutTrackerPresenter {

    /// Swaps the exercise `exerciseId` for `replacement`.
    ///
    /// Logged sets stay where they were done: two logged sets of barbell bench do not become
    /// dumbbell bench in the history. That exercise keeps only them, so it reads as done, and the
    /// replacement goes in right after it with the sets that were still open. With nothing logged
    /// there is nothing to keep, and the replacement takes the exercise's place. Either way the
    /// card moves to the replacement, and last time's figures and smart progression's suggestions
    /// are loaded for it, since both are keyed by the exercise's template.
    func insertSwappedExercise(after exerciseId: String, new replacement: ExerciseModel) {
        guard let authorId = interactor.currentUser?.userId,
              let index = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }

        let swap = Self.swapping(workoutSession.exercises[index], to: replacement, authorId: authorId)
        var exercises = workoutSession.exercises
        if let kept = swap.kept {
            exercises[index] = kept
            exercises.insert(swap.replacement, at: index + 1)
        } else {
            exercises[index] = swap.replacement
        }
        for position in exercises.indices { exercises[position].index = position + 1 }

        workoutSession.updateExercises(exercises)
        expandedExerciseId = swap.replacement.id
        currentExerciseIndex = exercises.firstIndex { $0.id == swap.replacement.id } ?? currentExerciseIndex
        loadPreviousWorkoutSession()
        loadProgressionSuggestions()
        refreshLiveActivity()
    }

    /// The swap itself, pure. `kept` is the old exercise holding only its logged sets, or `nil`
    /// when none were logged and the replacement simply takes its place (keeping its id).
    ///
    /// The replacement has as many working sets as were open, a left/right pair counted once and
    /// open warm-ups not at all: a warm-up for the old lift is not a working set of the new one.
    /// Three when none were open. It takes the targets of those open sets, renumbered from one, and
    /// the old exercise's place in a superset.
    static func swapping(
        _ old: WorkoutExerciseModel,
        to replacement: ExerciseModel,
        authorId: String
    ) -> (kept: WorkoutExerciseModel?, replacement: WorkoutExerciseModel) {
        let logged = old.sets.filter { $0.completedAt != nil }
        let openCount = old.sets.filter { $0.completedAt == nil && !$0.isWarmup }.pairedSetCount
        let perSide = WorkoutSessionModel.isPerSide(replacement)
        let mode = WorkoutSessionModel.trackingMode(for: replacement)

        var sets = WorkoutSessionModel.defaultSets(
            trackingMode: mode,
            authorId: authorId,
            targetCount: openCount > 0 ? openCount : 3,
            perSide: perSide
        )
        if perSide && old.isSplit { sets = sets.splittingSides() }

        let loggedCount = old.loggedSetCount
        var targets = old.setTargets
            .filter { $0.setNumber > loggedCount }
            .map { target in
                var target = target
                target.setNumber -= loggedCount
                return target
            }
        if targets.isEmpty { targets = [SetTarget(setNumber: 1, setType: .standard)] }

        let new = WorkoutExerciseModel(
            id: logged.isEmpty ? old.id : UUID().uuidString,
            authorId: authorId,
            templateId: replacement.id,
            name: replacement.name,
            trackingMode: mode,
            index: old.index + (logged.isEmpty ? 0 : 1),
            imageName: Constants.exerciseImageName(for: replacement),
            sets: sets,
            setTargets: targets,
            equipmentVariations: replacement.equipmentVariations,
            supersetGroupId: old.supersetGroupId
        )
        guard !logged.isEmpty else { return (nil, new) }

        var kept = old
        kept.sets = logged
        kept.supersetGroupId = nil
        return (kept, new)
    }
}
