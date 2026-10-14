//
//  WorkoutTrackerView+Exercises.swift
//  Compound
//
//  The list's sections: the open exercise's card and Add
//  Exercise, and the card's delegate.
//

import SwiftUI

extension WorkoutTrackerView {

    // MARK: - Exercises

    /// The card: the exercise on it, or the whole superset it belongs to.
    @ViewBuilder
    var currentExerciseSection: some View {
        // Each draws its own section, headed by the exercise's title row.
        if let current = presenter.currentExercise {
            if let members = ActiveWorkout.supersetBlock(containing: current.id, in: presenter.workoutSession.exercises) {
                supersetCard(members, current: current)
            } else {
                exerciseTrackerView(delegate(for: binding(for: current)))
            }
        }
    }

    /// By id, not index: see `replaceExercise`.
    private func binding(for current: WorkoutExerciseModel) -> Binding<WorkoutExerciseModel> {
        Binding(
            get: { presenter.workoutSession.exercises.first { $0.id == current.id } ?? current },
            set: { presenter.replaceExercise($0) }
        )
    }

    /// One card for a superset, built from each member's own card in pieces
    /// (`WorkoutTrackerPresenter.supersetCard`).
    private func supersetCard(_ members: [WorkoutExerciseModel], current: WorkoutExerciseModel) -> some View {
        let card = presenter.supersetCard(members, current: current.id)
        return SupersetBlockView(card: card) { exerciseId, piece in
            let index = members.firstIndex { $0.id == exerciseId } ?? 0
            var delegate = delegate(for: binding(for: members[index]))
            delegate.card?.piece = piece
            delegate.card?.memberLetter = ActiveWorkout.memberLabel(letter: card.letter, index: index)
            return exerciseTrackerView(delegate)
        }
    }

    func delegate(for exercise: Binding<WorkoutExerciseModel>) -> ExerciseTrackerDelegate {
        let current = exercise.wrappedValue
        let exerciseId = current.id
        var onDoLater: (@MainActor () -> Void)?
        if presenter.canDoLater(current) {
            onDoLater = { presenter.onDoLaterPressed(exerciseId) }
        }
        var onUpdateMesocycleNote: (@MainActor (String) -> Void)?
        if presenter.canEditMesocycleNote(current) {
            onUpdateMesocycleNote = { presenter.updateMesocycleNote($0, exerciseId: exerciseId) }
        }
        return ExerciseTrackerDelegate(
            exercise: exercise,
            lastExercise: presenter.previousExercise(for: current),
            allWorkoutExercises: presenter.workoutSession.exercises,
            progressionSuggestion: presenter.progressionSuggestion(for: current),
            previousNote: presenter.previousNote(for: current),
            onSetSupersetGroup: { exerciseId, groupId in
                presenter.setSupersetGroupId(groupId, forExerciseId: exerciseId)
            },
            onDeleteExercise: {
                presenter.deleteExercise(exerciseId)
            },
            onUpdateNote: { note in
                presenter.updateExerciseNotes(note, exerciseId: exerciseId)
            },
            onUpdateMesocycleNote: onUpdateMesocycleNote,
            onSwap: { replacement in
                presenter.insertSwappedExercise(after: exerciseId, new: replacement)
            },
            card: ExerciseCard(
                progressionNote: presenter.progressionNote(for: current),
                onProgressionNoteAcknowledged: { presenter.onProgressionNoteAcknowledged() },
                restTimer: presenter.restTimer(for: current),
                onDoLater: onDoLater,
                onLogSet: { setId, customRest in
                    presenter.logSet(setId, in: exerciseId, customRestSeconds: customRest, source: "row")
                },
                onCustomRestChanged: { setId, seconds in
                    presenter.onCustomRestChanged(setId: setId, seconds: seconds)
                },
                customRestSeconds: presenter.customRestSeconds,
                bodyweight: presenter.bodyweightContribution(for: current)
            )
        )
    }
}
