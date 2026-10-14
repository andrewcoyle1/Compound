//
//  WorkoutTrackerPresenter+Exercises.swift
//  Compound
//
//  The workout's exercises: adding from the picker, deleting, supersets, and the workout's
//  settings.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    /// Exercises picked part-way through, set up as the workout's own were: a unilateral lift
    /// gets rows it can split, and each gets last time's sets and a suggestion. The card stays
    /// on the exercise being worked.
    func addSelectedExercises() {
        let templates = self.pendingSelectedTemplates
        guard !templates.isEmpty, let userId = interactor.currentUser?.userId else { return }
        var updated = workoutSession.exercises
        let startIndex = updated.count
        var added: [WorkoutExerciseModel] = []
        for (offset, template) in templates.enumerated() {
            let index = startIndex + offset + 1
            let exercise = template.exercise
            let mode = WorkoutSessionModel.trackingMode(for: exercise)
            let targetCount = max(template.setTargets.count, 1)
            let defaultSets = WorkoutSessionModel.defaultSets(
                trackingMode: mode,
                authorId: userId,
                targetCount: targetCount,
                perSide: WorkoutSessionModel.isPerSide(exercise),
                setTargets: template.setTargets
            )
            let imageName = Constants.exerciseImageName(for: exercise)
            var newExercise = WorkoutExerciseModel(
                id: UUID().uuidString,
                authorId: userId,
                templateId: exercise.id,
                name: exercise.name,
                trackingMode: mode,
                index: index,
                notes: nil,
                imageName: imageName,
                sets: defaultSets,
                setTargets: template.setTargets
            )
            newExercise.takeLoad(
                from: exercise,
                gym: interactor.workoutGymProfile,
                preference: interactor.getPreference(templateId: exercise.id)
            )
            updated.append(newExercise)
            added.append(newExercise)
        }
        let card = currentExercise?.id ?? added.first?.id
        workoutSession.updateExercises(updated)
        focusCard(on: card)
        captureProgressionBaseline(of: added)
        loadPrevious(for: added)
        loadProgressionSuggestions(for: added)

        refreshLiveActivity()

        self.pendingSelectedTemplates = []
    }

    /// Takes the exercise out. A superset partner left on its own is no longer a superset, and a
    /// card on the deleted exercise moves to the next one in the workout's order with sets left.
    /// A rest that followed one of its sets is called off by `cancelRestIfRestedSetRemoved`.
    func deleteExercise(_ exerciseId: String) {
        var updated = workoutSession.exercises
        guard let idx = updated.firstIndex(where: { $0.id == exerciseId }) else { return }
        let removed = updated.remove(at: idx)
        if let groupId = removed.supersetGroupId {
            let partners = updated.indices.filter { updated[$0].supersetGroupId == groupId }
            if partners.count == 1 { updated[partners[0]].supersetGroupId = nil }
        }
        for index in updated.indices { updated[index].index = index + 1 }

        var card = currentExercise?.id
        if card == exerciseId {
            let next = updated.indices.first { $0 >= idx && !isComplete(updated[$0]) }
                ?? updated.indices.first { !isComplete(updated[$0]) }
            card = next.map { updated[$0].id }
        }
        workoutSession.updateExercises(updated)
        focusCard(on: card)

        refreshLiveActivity()
    }

    /// Puts the card on `exerciseId`, or back on the first exercise with sets left without one.
    private func focusCard(on exerciseId: String?) {
        let exercises = workoutSession.exercises
        if let exerciseId, let index = exercises.firstIndex(where: { $0.id == exerciseId }) {
            cardExerciseId = exerciseId
            currentExerciseIndex = index
        } else {
            cardExerciseId = nil
            syncCurrentExerciseIndexToFirstIncomplete(in: exercises)
        }
    }

    func onWorkoutSettingsPressed() {
        router.showWorkoutSettingsView(delegate: WorkoutSettingsDelegate())
    }

    func setSupersetGroupId(_ groupId: String?, forExerciseId exerciseId: String) {
        guard var exercise = workoutSession.exercises.first(where: { $0.id == exerciseId }) else { return }
        exercise.supersetGroupId = groupId
        replaceExercise(exercise)
    }

    /// Writes back an edited exercise, by id: the card's binding, a superset change, an undo. By
    /// id, not index, because a binding by index can be read while the exercise it held is being
    /// removed, and would then point at another exercise or past the end.
    func replaceExercise(_ updated: WorkoutExerciseModel) {
        guard let index = workoutSession.exercises.firstIndex(where: { $0.id == updated.id }) else { return }
        var exercises = workoutSession.exercises
        exercises[index] = updated
        workoutSession.updateExercises(exercises)
    }

    func presentAddExercise() {
        router.showExercisesPickerView(
            delegate: ExercisesPickerDelegate(
                addedExercises: Binding(
                    get: { self.pendingSelectedTemplates },
                    set: { self.pendingSelectedTemplates = $0 }
                )
            )
        )
    }
    
}
