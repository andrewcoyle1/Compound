//
//  WorkoutTrackerPresenter+SessionChanges.swift
//  Compound
//
//  Split out of WorkoutTrackerPresenter.swift to keep it under the type-body and file-length
//  limits, so later work adds its logic here rather than in the main file. Reacting to an edited
//  or logged set: committing edits to sibling sets and moving focus once an exercise is done.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    func updateSet(_ updatedSet: WorkoutSetModel, in exerciseId: String) {
        recordUndo(replacing: updatedSet, in: exerciseId)
        // An edit still being typed into another set is over. This set keeps what the caller
        // passed, which is what the user was looking at when they acted.
        commitPendingEdit(sparing: updatedSet.id)
        guard let exerciseIndex = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = workoutSession.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == updatedSet.id }) else {
            return
        }
        let exerciseBefore = workoutSession.exercises[exerciseIndex]
        let isLogged = exerciseBefore.sets[setIndex].completedAt == nil && updatedSet.completedAt != nil

        var updatedExercises = workoutSession.exercises
        updatedExercises[exerciseIndex].sets[setIndex] = updatedSet
        if interactor.workoutSettings.propagateChanges {
            updatedExercises[exerciseIndex].sets = ActiveWorkout.propagate(
                edit: updatedSet,
                original: exerciseBefore.sets[setIndex],
                in: updatedExercises[exerciseIndex].sets
            )
        }

        isProcessingUpdateSet = true
        workoutSession.updateExercises(updatedExercises)
        isProcessingUpdateSet = false

        if isLogged { moveFocus(afterLogging: updatedSet.id) }

        // A logged set is the one change worth not waiting for.
        if isLogged { flushSave() }
        refreshLiveActivity()
    }

    /// True when the exercise has sets and every one of them is logged.
    func isComplete(_ exercise: WorkoutExerciseModel) -> Bool {
        !exercise.sets.isEmpty && exercise.sets.allSatisfy { $0.completedAt != nil }
    }

    func handleWorkoutSessionChange(from oldSession: WorkoutSessionModel) {
        guard !isProcessingUpdateSet else { return }
        recordUndo(from: oldSession)
        notePendingEdit(comparedTo: oldSession)
        cancelRestIfUndone(comparedTo: oldSession)
        guard let setId = firstNewlyCompletedSetId(comparedTo: oldSession) else { return }

        // A set logged from the Live Activity or a widget intent lands here rather than in
        // `updateSet`, and moves focus the same way.
        moveFocus(afterLogging: setId)

        // Logged elsewhere and adopted here, smart progression re-suggests what is left as it
        // does for a set logged on this screen. Only an adopted save equals the saved session: a
        // write from this screen waits out the save's debounce.
        if workoutSession == interactor.activeSession,
           let exercise = workoutSession.exercises.first(where: { $0.sets.contains { $0.id == setId } }),
           let set = exercise.sets.first(where: { $0.id == setId }) {
            applyLiveProgression(after: set, in: exercise.id)
        }

        refreshLiveActivity()
    }

    /// The set rows write straight into `workoutSession` through their bindings, a keystroke at a
    /// time, so a typed weight or reps arrives here rather than through `updateSet`. A keystroke
    /// only notes which set is being edited and what it held before the first key; the edit is
    /// carried onto its siblings once it is over (`commitPendingEdit`). Carrying it per key matched
    /// siblings against whatever had been typed so far, and rewrote a back-off set that happened
    /// to equal it.
    ///
    /// Only when exactly one set's weight or reps changed: that is what a user's edit looks like.
    /// A change to several at once is the screen's own (a progression re-suggestion, an adopted
    /// save) and is not the user's to copy.
    func notePendingEdit(comparedTo oldSession: WorkoutSessionModel) {
        guard interactor.workoutSettings.propagateChanges else { return }

        var originals: [WorkoutSetModel] = []
        for exercise in workoutSession.exercises {
            guard let oldExercise = oldSession.exercises.first(where: { $0.id == exercise.id }) else { continue }
            for set in exercise.sets {
                guard let original = oldExercise.sets.first(where: { $0.id == set.id }),
                      original.weightKg != set.weightKg || original.reps != set.reps else { continue }
                originals.append(original)
            }
        }
        guard originals.count == 1, let original = originals.first else { return }
        // Still the same set: keep what it held before its first key.
        guard savePath.pendingEdit?.id != original.id else { return }

        commitPendingEdit(sparing: original.id)
        savePath.pendingEdit = original
    }

    /// Carries the edit being typed onto its siblings (`ActiveWorkout.propagate`). Called when the
    /// edit is over: another set is edited, a set is logged, the keyboard hides, or the session is
    /// flushed.
    ///
    /// `sparedSetId` is a set the caller is writing itself, which keeps the value the user sees in
    /// it rather than taking the committed one.
    func commitPendingEdit(sparing sparedSetId: String? = nil) {
        guard let original = savePath.pendingEdit else { return }
        savePath.pendingEdit = nil
        guard interactor.workoutSettings.propagateChanges,
              let exerciseIndex = workoutSession.exercises.firstIndex(where: { $0.sets.contains { $0.id == original.id } })
        else { return }

        let sets = workoutSession.exercises[exerciseIndex].sets
        guard let edit = sets.first(where: { $0.id == original.id }) else { return }
        var propagated = ActiveWorkout.propagate(edit: edit, original: original, in: sets)
        if let spared = sets.firstIndex(where: { $0.id == sparedSetId }) {
            propagated[spared] = sets[spared]
        }
        guard propagated != sets else { return }

        var updatedExercises = workoutSession.exercises
        updatedExercises[exerciseIndex].sets = propagated
        isProcessingUpdateSet = true
        workoutSession.updateExercises(updatedExercises)
        isProcessingUpdateSet = false
    }

    /// The first set that flipped incomplete → complete relative to `oldSession`, or nil when
    /// nothing was newly logged.
    func firstNewlyCompletedSetId(comparedTo oldSession: WorkoutSessionModel) -> String? {
        var oldSets: [String: WorkoutSetModel] = [:]
        for exercise in oldSession.exercises {
            for set in exercise.sets {
                oldSets[set.id] = set
            }
        }

        return workoutSession.exercises.lazy
            .flatMap(\.sets)
            .first { oldSets[$0.id]?.completedAt == nil && $0.completedAt != nil }?
            .id
    }
}
