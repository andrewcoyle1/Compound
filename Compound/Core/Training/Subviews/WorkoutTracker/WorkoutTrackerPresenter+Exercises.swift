//
//  WorkoutTrackerPresenter+Exercises.swift
//  Compound
//
//  Split out of WorkoutTrackerPresenter.swift, which exceeded the 750-line file and
//  500-line type-body limits.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    func addSelectedExercises() {
        let templates = self.pendingSelectedTemplates
        guard !templates.isEmpty, let userId = interactor.currentUser?.userId else { return }
        var updated = workoutSession.exercises
        let startIndex = updated.count
        for (offset, template) in templates.enumerated() {
            let index = startIndex + offset + 1
            let exercise = template.exercise
            let mode = WorkoutSessionModel.trackingMode(for: exercise)
            let targetCount = max(template.setTargets.count, 1)
            let defaultSets = WorkoutSessionModel.defaultSets(
                trackingMode: mode,
                authorId: userId,
                targetCount: targetCount
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
        }
        workoutSession.updateExercises(updated)
        syncCurrentExerciseIndexToFirstIncomplete(in: updated)
        if currentExerciseIndex < updated.count {
            expandedExerciseId = updated[currentExerciseIndex].id
        }

        refreshLiveActivity()

        self.pendingSelectedTemplates = []
    }

    func deleteExercise(_ exerciseId: String) {
        var updated = workoutSession.exercises
        guard let idx = updated.firstIndex(where: { $0.id == exerciseId }) else { return }
        updated.remove(at: idx)
        for index in updated.indices { updated[index].index = index + 1 }
        workoutSession.updateExercises(updated)
        if expandedExerciseId == exerciseId { expandedExerciseId = nil }
        syncCurrentExerciseIndexToFirstIncomplete(in: updated)

        refreshLiveActivity()
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
