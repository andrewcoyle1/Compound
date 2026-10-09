//
//  WorkoutTrackerPresenter+Exercises.swift
//  Compound
//
//  Split out of WorkoutTrackerPresenter.swift, which exceeded the 750-line file and
//  500-line type-body limits.
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
            let newExercise = WorkoutExerciseModel(
                id: UUID().uuidString,
                authorId: userId,
                templateId: exercise.id,
                name: exercise.name,
                trackingMode: mode,
                index: index,
                notes: nil,
                imageName: imageName,
                sets: defaultSets,
                setTargets: template.setTargets,
                chosenVariationId: nil,
                equipmentVariations: exercise.equipmentVariations
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
            expandedExerciseId = exerciseId
            currentExerciseIndex = index
        } else {
            expandedExerciseId = nil
            syncCurrentExerciseIndexToFirstIncomplete(in: exercises)
        }
    }

    func onWorkoutSettingsPressed() {
        router.showWorkoutSettingsView(delegate: WorkoutSettingsDelegate())
    }

    func moveExercises(from source: IndexSet, to destination: Int) {
        var updated = workoutSession.exercises
        updated.move(fromOffsets: source, toOffset: destination)
        applyReorderedExercises(updated, movedFrom: source.first, movedTo: destination)

        refreshLiveActivity()
    }

    func setSupersetGroupId(_ groupId: String?, forExerciseId exerciseId: String) {
        guard let idx = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        workoutSession.exercises[idx].supersetGroupId = groupId
    }

    func reorderExercises(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex != targetIndex else { return }
        var updated = workoutSession.exercises
        let element = updated.remove(at: sourceIndex)
        updated.insert(element, at: targetIndex)
        applyReorderedExercises(updated, movedFrom: sourceIndex, movedTo: targetIndex)
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
