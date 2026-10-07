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

    /// The card: the exercise on it, or the whole superset it belongs to.
    @ViewBuilder
    var currentExerciseSection: some View {
        if let current = presenter.currentExercise {
            Section {
                if let members = ActiveWorkout.supersetBlock(containing: current.id, in: presenter.workoutSession.exercises) {
                    supersetCard(members, current: current)
                } else {
                    exerciseTrackerView(delegate(for: binding(for: current)), { duration in
                        presenter.startRestTimer(durationSeconds: duration)
                    })
                }
            }
            .listSectionMargins(.top, Spacing.s)
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

    /// One card for a superset, built from each member's own card in pieces. The correction row
    /// and a rest after a member's set sit under that set, as `delegate(for:)` places them; a
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
            onUndoManager: { presenter.onUndoManagerChanged($0) },
            piece: { exerciseId, piece, showAutoRanges in
                let index = members.firstIndex { $0.id == exerciseId } ?? 0
                let member = members[index]
                var delegate = delegate(for: binding(for: member))
                delegate.card?.piece = piece
                delegate.card?.showAutoRanges = showAutoRanges
                delegate.card?.memberLetter = ActiveWorkout.letter(index)
                delegate.card?.onUndoManager = nil
                // Smart progression's note speaks for the exercise the log button is on.
                if member.id != current.id { delegate.card?.progressionNote = nil }
                return exerciseTrackerView(delegate, { duration in
                    presenter.startRestTimer(durationSeconds: duration)
                })
            }
        )
    }

    @ViewBuilder
    var upNextSection: some View {
        let upNext = presenter.upNextExercises
        if !upNext.isEmpty {
            Section {
                ForEach(upNext) { exercise in
                    exerciseRow(exercise, isDone: false)
                        .accessibilityActions { upNextActions(for: exercise) }
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
            // The row leaves the list as its exercise goes onto the card; VoiceOver goes on to
            // the button that logs its first set rather than to wherever the row was.
            returnFocusToPrimaryCTA()
        } label: {
            ListRow(
                title: exercise.name,
                subtitle: presenter.upNextSummary(for: exercise),
                imageName: exercise.imageName,
                resizingMode: .fit,
                initialsWhenMissing: true,
                // No chevron: a tap opens the exercise on the card in place rather than pushing.
                accessory: isDone
                    ? .custom(AnyView(Image(systemName: Symbol.success).foregroundStyle(.success).accessibilityLabel("Done")))
                    : supersetLabel(for: exercise).map { ListRow.Accessory.custom(AnyView(Chip($0, systemImage: Symbol.superset, tint: .superset))) } ?? .none
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

    /// The long-press menu and the drag handles, as named actions: VoiceOver's Actions rotor,
    /// Switch Control's menu and Voice Control's "show actions" reach them without a gesture.
    @ViewBuilder
    private func upNextActions(for exercise: WorkoutExerciseModel) -> some View {
        Button("Do Next") { presenter.onDoNextPressed(exercise.id) }
        if presenter.canDoLater(exercise) {
            Button("Do Later") { presenter.onDoLaterPressed(exercise.id) }
        }
        if presenter.upNextMoveDestination(of: exercise.id, by: -1) != nil {
            Button("Move Up") { presenter.onUpNextMovePressed(exercise.id, by: -1) }
        }
        if presenter.upNextMoveDestination(of: exercise.id, by: 1) != nil {
            Button("Move Down") { presenter.onUpNextMovePressed(exercise.id, by: 1) }
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

    /// "Superset A", "Circuit B": the superset's letter, one per superset in the workout.
    func supersetLabel(for exercise: WorkoutExerciseModel) -> String? {
        ActiveWorkout.supersetLabel(for: exercise, in: presenter.workoutSession.exercises)
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
                correction: presenter.correction(for: current),
                onCorrection: { setId, action in
                    presenter.onCorrection(action, setId: setId, in: exerciseId)
                },
                onUndoManager: { presenter.onUndoManagerChanged($0) },
                bodyweight: presenter.bodyweightContribution(for: current)
            )
        )
    }
}
