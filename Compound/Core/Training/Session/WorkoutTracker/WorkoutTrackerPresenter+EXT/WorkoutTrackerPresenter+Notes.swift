//
//  WorkoutTrackerPresenter+Notes.swift
//  Compound
//
//  The notes a workout carries: on each exercise, its session note (this workout only), its
//  exercise note (every workout) and, in a mesocycle, its mesocycle note (that slot of that day);
//  and one for the whole workout.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    /// The note left on this exercise the last time it was done, for the header's note sheet to
    /// show as a hint. "Last time" is the session `loadPreviousWorkoutSession()` resolved, the same
    /// one the Prev column reads, so the hint and the figures beside it always agree.
    func previousNote(for exercise: WorkoutExerciseModel) -> String? {
        let trimmed = previousExercise(for: exercise)?.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Whether the exercise came from a slot of the mesocycle day plan this workout is, so its
    /// mesocycle note can be edited. Not for an exercise added mid-workout, a workout from a
    /// template, or a slot the plan has since lost.
    func canEditMesocycleNote(_ exercise: WorkoutExerciseModel) -> Bool {
        mesocycle(settingNote: nil, on: exercise) != nil
    }

    /// The mesocycle note: this workout's copy at once, then the day plan's slot, so every later
    /// week of that day shows it. Blank clears it.
    func updateMesocycleNote(_ note: String, exerciseId: String) {
        guard let index = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? nil : trimmed
        var exercises = workoutSession.exercises
        exercises[index].planNotes = value
        workoutSession.updateExercises(exercises)
        interactor.playHaptic(option: .success)
        interactor.trackEvent(event: Event.mesocycleNoteSaved)
        guard let mesocycle = mesocycle(settingNote: value, on: exercises[index]) else { return }
        Task {
            do {
                try await interactor.saveMesocycle(mesocycle: mesocycle)
            } catch {
                interactor.playHaptic(option: .error)
                interactor.trackEvent(event: Event.mesocycleNoteSaveFail(error: error))
                router.showAlert(
                    title: String(localized: "Unable to Save Note"),
                    subtitle: String(localized: "The note is on this workout, but not yet on your mesocycle. Please try again."),
                    buttons: nil
                )
            }
        }
    }

    private func mesocycle(settingNote note: String?, on exercise: WorkoutExerciseModel) -> Mesocycle? {
        guard let mesocycleId = workoutSession.mesocycleId,
              let dayPlanId = workoutSession.workoutTemplateId,
              let slotId = exercise.planSlotId,
              let mesocycle = interactor.mesocycles.first(where: { $0.id == mesocycleId })
        else { return nil }
        return mesocycle.settingNote(note, dayPlanId: dayPlanId, slotId: slotId)
    }

    // MARK: - The workout's and the exercise's notes

    func onWorkoutNotesPressed() {
        // Seeded from the session each time, so a resumed workout's note is not wiped by a save
        // and a cancelled edit does not linger as the draft.
        workoutNotes = workoutSession.notes ?? ""
        router.showWorkoutNotesView(
            delegate: WorkoutNotesDelegate(
                notes: Binding(
                    get: {
                        self.workoutNotes
                    },
                    set: { newValue in
                        self.workoutNotes = newValue
                    }
                ),
                onSave: {
                    self.updateWorkoutNotes()
                }
            )
        )
    }

    func updateWorkoutNotes() {
        let trimmed = workoutNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        workoutSession.notes = trimmed.isEmpty ? nil : trimmed
        interactor.playHaptic(option: .success)
        interactor.trackEvent(event: Event.workoutNotesSaved)
    }

    func updateExerciseNotes(_ notes: String, exerciseId: String) {
        guard let exerciseIndex = workoutSession.exercises.firstIndex(where: { $0.id == exerciseId }) else {
            return
        }

        var updatedExercises = workoutSession.exercises
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedExercises[exerciseIndex].notes = trimmed.isEmpty ? nil : trimmed
        workoutSession.updateExercises(updatedExercises)
        interactor.playHaptic(option: .success)
        interactor.trackEvent(event: Event.exerciseNotesSaved)
    }
}
