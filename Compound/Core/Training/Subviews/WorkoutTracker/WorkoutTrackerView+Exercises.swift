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

    /// By id, not index: a binding by index can be read while the exercise it held is being
    /// removed, and would then point at another exercise or past the end.
    private func binding(for current: WorkoutExerciseModel) -> Binding<WorkoutExerciseModel> {
        Binding(
            get: { presenter.workoutSession.exercises.first { $0.id == current.id } ?? current },
            set: { updated in
                guard let index = presenter.workoutSession.exercises.firstIndex(where: { $0.id == current.id }) else { return }
                presenter.workoutSession.exercises[index] = updated
            }
        )
    }

    /// One card for a superset, built from each member's own card in pieces. A rest after a
    /// member's set sits under that set, as `delegate(for:)` places it; a
    /// rest after a set outside the superset is drawn once, above the rows.
    private func supersetCard(_ members: [WorkoutExerciseModel], current: WorkoutExerciseModel) -> some View {
        let timers = members.compactMap { presenter.restTimer(for: $0) }
        let restBefore = timers.contains { $0.anchor != .top } ? nil : timers.first
        return SupersetBlockView(
            members: members,
            rows: ActiveWorkout.blockRows(members),
            nextSetId: ActiveWorkout.nextSetId(inBlock: members, current: current.id),
            showsColumnHeadings: ActiveWorkout.blockSharesColumns(members, units: presenter.units(for:)),
            restBefore: restBefore,
            piece: { exerciseId, piece in
                let index = members.firstIndex { $0.id == exerciseId } ?? 0
                let member = members[index]
                var delegate = delegate(for: binding(for: member))
                delegate.card?.piece = piece
                delegate.card?.memberLetter = ActiveWorkout.letter(index)
                // Smart progression's note speaks for the exercise the log button is on.
                if member.id != current.id { delegate.card?.progressionNote = nil }
                return exerciseTrackerView(delegate)
            }
        )
    }

    var addExerciseSection: some View {
        Section {
            Button {
                presenter.presentAddExercise()
            } label: {
                Label("Add Exercise", systemImage: Symbol.add)
                    // A text style of its own: the audit credits Dynamic Type only to the text's
                    // own font, and with the strip on this row is on screen for every audit pass.
                    .font(.body)
            }
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
                progressionNote: presenter.progressionNote,
                onProgressionNoteAcknowledged: { presenter.onProgressionNoteAcknowledged() },
                restTimer: presenter.restTimer(for: current),
                onDoLater: onDoLater,
                onLogSet: { setId, customRest in
                    presenter.logSet(setId, in: exerciseId, customRestSeconds: customRest, source: "row")
                },
                onCustomRestChanged: { setId, seconds in
                    presenter.customRestSeconds[setId] = seconds
                },
                bodyweight: presenter.bodyweightContribution(for: current),
                showsImage: dynamicTypeSize.isAccessibilitySize
            )
        )
    }
}
