//
//  WorkoutTrackerPresenter+SessionChanges.swift
//  Compound
//
//  Split out of WorkoutTrackerPresenter.swift to keep it under the type-body and file-length
//  limits, so later work adds its logic here rather than in the main file. Reacting to an edited
//  or logged set: propagating edits to sibling sets and moving focus once an exercise is done.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    func updateSet(_ updatedSet: WorkoutSetModel, in exerciseId: String) {
        guard let exerciseIndex = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = workoutSession.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == updatedSet.id }) else {
            return
        }
        let exerciseBefore = workoutSession.exercises[exerciseIndex]
        let wasExerciseCompleteBefore = isComplete(exerciseBefore)

        var updatedExercises = workoutSession.exercises
        updatedExercises[exerciseIndex].sets[setIndex] = updatedSet
        propagateChanges(
            of: updatedSet,
            replacing: exerciseBefore.sets[setIndex],
            at: setIndex,
            in: &updatedExercises[exerciseIndex].sets
        )

        let isExerciseCompleteNow = isComplete(updatedExercises[exerciseIndex])
        isProcessingUpdateSet = true
        workoutSession.updateExercises(updatedExercises)
        isProcessingUpdateSet = false

        if !wasExerciseCompleteBefore && isExerciseCompleteNow {
            advanceAfterExerciseCompletion(exerciseIndex: exerciseIndex, in: updatedExercises)
        } else if exerciseBefore.sets[setIndex].completedAt == nil, updatedSet.completedAt != nil {
            advanceWithinSuperset(exerciseIndex: exerciseIndex, in: updatedExercises)
        }

        refreshLiveActivity()
    }

    /// True when the exercise has sets and every one of them is logged.
    ///
    /// Not private: `WorkoutTrackerPresenter+Superset` skips partners that are already finished.
    func isComplete(_ exercise: WorkoutExerciseModel) -> Bool {
        !exercise.sets.isEmpty && exercise.sets.allSatisfy { $0.completedAt != nil }
    }

    /// Copies a weight/reps edit onto sibling sets that still hold the previous values, when
    /// the propagate-changes setting is on.
    ///
    /// Kept within a side: typing a heavier weight on the left arm must not quietly move the right
    /// arm's sets too, because the two limbs are not equally strong and that is why they are
    /// logged apart.
    func propagateChanges(
        of updatedSet: WorkoutSetModel,
        replacing original: WorkoutSetModel,
        at setIndex: Int,
        in sets: inout [WorkoutSetModel]
    ) {
        guard interactor.workoutSettings.propagateChanges, updatedSet.completedAt == nil else { return }

        let weightChanged = original.weightKg != updatedSet.weightKg
        let repsChanged = original.reps != updatedSet.reps
        guard weightChanged || repsChanged else { return }

        for index in sets.indices where index != setIndex {
            var sibling = sets[index]
            guard sibling.side == updatedSet.side,
                  sibling.completedAt == nil,
                  sibling.weightKg == original.weightKg,
                  sibling.reps == original.reps else { continue }
            if weightChanged { sibling.weightKg = updatedSet.weightKg }
            if repsChanged { sibling.reps = updatedSet.reps }
            sets[index] = sibling
        }
    }

    /// Moves focus to the next exercise with sets left once every set in `exerciseIndex` is
    /// logged, as the log button's Next does: one finished earlier is skipped. Shared by
    /// `updateSet` and `handleWorkoutSessionChange`, which both used to inline it.
    func advanceAfterExerciseCompletion(exerciseIndex: Int, in exercises: [WorkoutExerciseModel]) {
        let nextIndex = exercises.indices.first { $0 > exerciseIndex && !isComplete(exercises[$0]) }

        if let nextIndex, interactor.workoutSettings.exerciseAutoNext {
            expandedExerciseId = exercises[nextIndex].id
            currentExerciseIndex = nextIndex
        } else if nextIndex == nil, expandedExerciseId == exercises[exerciseIndex].id {
            expandedExerciseId = nil
        }
    }

    func handleWorkoutSessionChange(from oldSession: WorkoutSessionModel) {
        guard !isProcessingUpdateSet else { return }
        propagateEdit(comparedTo: oldSession)
        cancelRestIfUndone(comparedTo: oldSession)
        guard let exerciseIndex = firstNewlyCompletedSetExerciseIndex(comparedTo: oldSession) else { return }

        let exercise = workoutSession.exercises[exerciseIndex]
        let wasExerciseCompleteBefore = oldSession.exercises
            .first { $0.id == exercise.id }
            .map(isComplete) ?? false

        if !wasExerciseCompleteBefore && isComplete(exercise) {
            advanceAfterExerciseCompletion(exerciseIndex: exerciseIndex, in: workoutSession.exercises)
        } else {
            // A set logged from the Live Activity or a widget intent lands here rather than in
            // `updateSet`, and moves focus the same way.
            advanceWithinSuperset(exerciseIndex: exerciseIndex, in: workoutSession.exercises)
        }

        refreshLiveActivity()
    }

    /// The set rows write straight into `workoutSession` through their bindings, so a typed weight
    /// or reps arrives here rather than through `updateSet`. Carries it onto the sibling sets the
    /// same way `updateSet` does.
    ///
    /// Only when exactly one set's weight or reps changed: that is what a user's edit looks like.
    /// A change to several at once is the screen's own (a progression re-suggestion, an adopted
    /// save) and is not the user's to copy.
    func propagateEdit(comparedTo oldSession: WorkoutSessionModel) {
        guard interactor.workoutSettings.propagateChanges else { return }

        var edits: [(exerciseIndex: Int, original: WorkoutSetModel)] = []
        for (exerciseIndex, exercise) in workoutSession.exercises.enumerated() {
            guard let oldExercise = oldSession.exercises.first(where: { $0.id == exercise.id }) else { continue }
            for set in exercise.sets {
                guard let original = oldExercise.sets.first(where: { $0.id == set.id }),
                      original.weightKg != set.weightKg || original.reps != set.reps else { continue }
                edits.append((exerciseIndex, original))
            }
        }
        guard edits.count == 1, let edit = edits.first,
              let setIndex = workoutSession.exercises[edit.exerciseIndex].sets.firstIndex(where: { $0.id == edit.original.id })
        else { return }

        var updatedExercises = workoutSession.exercises
        propagateChanges(
            of: updatedExercises[edit.exerciseIndex].sets[setIndex],
            replacing: edit.original,
            at: setIndex,
            in: &updatedExercises[edit.exerciseIndex].sets
        )
        guard updatedExercises != workoutSession.exercises else { return }

        isProcessingUpdateSet = true
        workoutSession.updateExercises(updatedExercises)
        isProcessingUpdateSet = false
    }

    /// The first exercise holding a set that flipped incomplete → complete relative to
    /// `oldSession`, or nil when nothing was newly logged.
    func firstNewlyCompletedSetExerciseIndex(comparedTo oldSession: WorkoutSessionModel) -> Int? {
        var oldSets: [String: WorkoutSetModel] = [:]
        for exercise in oldSession.exercises {
            for set in exercise.sets {
                oldSets[set.id] = set
            }
        }

        return workoutSession.exercises.firstIndex { exercise in
            exercise.sets.contains { set in
                oldSets[set.id]?.completedAt == nil && set.completedAt != nil
            }
        }
    }
}
