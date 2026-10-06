//
//  WorkoutTrackerView+Exercises.swift
//  Compound
//
//  Split out of WorkoutTrackerView.swift to keep it under the file-length limits, so later work
//  adds its views in their own files. The list's sections: the open exercise's card, Up Next,
//  Completed and Add Exercise, and the card's delegate.
//

import SwiftUI

extension WorkoutTrackerView {

    // MARK: - Exercises

    @ViewBuilder
    var currentExerciseSection: some View {
        if let current = presenter.currentExercise {
            // By id, not index: a binding by index can be read while the exercise it held is being
            // removed, and would then point at another exercise or past the end.
            let exercise = Binding(
                get: { presenter.workoutSession.exercises.first { $0.id == current.id } ?? current },
                set: { updated in
                    guard let index = presenter.workoutSession.exercises.firstIndex(where: { $0.id == current.id }) else { return }
                    presenter.workoutSession.exercises[index] = updated
                }
            )
            Section {
                exerciseTrackerView(delegate(for: exercise), { duration in
                    presenter.startRestTimer(durationSeconds: duration)
                })
            }
            .listSectionMargins(.top, Spacing.s)
        }
    }

    @ViewBuilder
    var upNextSection: some View {
        let upNext = presenter.upNextExercises
        if !upNext.isEmpty {
            Section {
                ForEach(upNext) { exercise in
                    exerciseRow(exercise, isDone: false)
                }
                .onMove { source, destination in
                    presenter.moveUpNext(from: source, to: destination)
                }
                // Drag handles on demand: a long press on a row is its Do Next / Do Later menu.
                if upNext.count > 1 {
                    Button {
                        presenter.onReorderPressed()
                    } label: {
                        Label(
                            presenter.editMode.isEditing ? "Done Reordering" : "Reorder",
                            systemImage: presenter.editMode.isEditing ? Symbol.success : Symbol.reorder
                        )
                        .font(.rowTitle)
                    }
                    .accessibilityIdentifier("WorkoutTracker.reorderButton")
                }
            } header: {
                Text("Up Next")
                    .font(.label.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    var completedSection: some View {
        let completed = presenter.completedExercises
        if !completed.isEmpty {
            Section {
                ForEach(completed) { exercise in
                    exerciseRow(exercise, isDone: true)
                }
            } header: {
                Text("Completed")
                    .font(.label.weight(.semibold))
            }
        }
    }

    /// One line per exercise not on the card. A tap opens it on the card.
    func exerciseRow(_ exercise: WorkoutExerciseModel, isDone: Bool) -> some View {
        Button {
            presenter.onExerciseSelected(exercise.id)
        } label: {
            ListRow(
                title: exercise.name,
                subtitle: presenter.upNextSummary(for: exercise),
                imageName: exercise.imageName,
                resizingMode: .fit,
                initialsWhenMissing: true,
                accessory: isDone
                    ? .custom(AnyView(Image(systemName: Symbol.success).foregroundStyle(.success).accessibilityLabel("Done")))
                    : .chevron
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this exercise")
        // Waiting on a machine: bring an exercise forward, or put it off, without dragging.
        .contextMenu {
            if !isDone {
                Button {
                    presenter.onDoNextPressed(exercise.id)
                } label: {
                    Label("Do Next", systemImage: Symbol.doNext)
                }
                Button {
                    presenter.onDoLaterPressed(exercise.id)
                } label: {
                    Label("Do Later", systemImage: Symbol.doLater)
                }
            }
        }
    }

    var addExerciseSection: some View {
        Section {
            Button {
                presenter.presentAddExercise()
            } label: {
                Label("Add Exercise", systemImage: Symbol.add)
            }
        }
    }

    /// "Superset A", "Circuit C": the exercise's letter within its group.
    func supersetLabel(for exercise: WorkoutExerciseModel) -> String? {
        guard let groupId = exercise.supersetGroupId else { return nil }
        let group = presenter.workoutSession.exercises.filter { $0.supersetGroupId == groupId }
        let letters = ["A", "B", "C", "D", "E", "F"]
        guard let idx = group.firstIndex(where: { $0.id == exercise.id }), idx < letters.count else { return nil }
        let prefix = group.count > 2 ? String(localized: "Circuit") : String(localized: "Superset")
        return "\(prefix) \(letters[idx])"
    }

    func delegate(for exercise: Binding<WorkoutExerciseModel>) -> ExerciseTrackerDelegate {
        let current = exercise.wrappedValue
        let exerciseId = current.id
        var onDoLater: (@MainActor () -> Void)?
        if presenter.canDoLater(current) {
            onDoLater = { presenter.onDoLaterPressed(exerciseId) }
        }
        return ExerciseTrackerDelegate(
            exercise: exercise,
            lastExercise: presenter.previousExercises[current.templateId],
            isExpanded: .constant(true),
            allWorkoutExercises: presenter.workoutSession.exercises,
            supersetLabel: supersetLabel(for: current),
            progressionSuggestion: presenter.progressionSuggestions[current.templateId],
            previousNote: presenter.previousNote(forExerciseTemplateId: current.templateId),
            onSetSupersetGroup: { exerciseId, groupId in
                presenter.setSupersetGroupId(groupId, forExerciseId: exerciseId)
            },
            onDeleteExercise: {
                presenter.deleteExercise(exerciseId)
            },
            onSetCompleted: { completedSet, _ in
                presenter.applyLiveProgression(after: completedSet, in: exerciseId)
            },
            onUpdateNote: { note in
                presenter.updateExerciseNotes(note, exerciseId: exerciseId)
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
                }
            )
        )
    }
}
