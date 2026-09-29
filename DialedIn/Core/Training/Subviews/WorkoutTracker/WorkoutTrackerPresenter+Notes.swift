//
//  WorkoutTrackerPresenter+Notes.swift
//  DialedIn
//
//  The notes a workout carries: one per exercise, written from its header, and one for the
//  session, written on the finish screen.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    /// The note left on this exercise the last time it was done, for the header's note sheet to
    /// show as a hint. "Last time" is the session `loadPreviousWorkoutSession()` resolved, the same
    /// one the Prev column reads, so the hint and the figures beside it always agree.
    func previousNote(forExerciseTemplateId templateId: String) -> String? {
        let trimmed = previousExercises[templateId]?.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// The finish screen: the session note, then Finish. Cancelling leaves the workout running.
    ///
    /// The workout ends only once the sheet is fully dismissed, because finishing dismisses the
    /// tracker itself and that must not race the sheet on top of it.
    func onFinishPressed() {
        workoutNotes = workoutSession.notes ?? ""
        var didConfirm = false
        router.showWorkoutNotesView(
            delegate: WorkoutNotesDelegate(
                notes: Binding(
                    get: { self.workoutNotes },
                    set: { self.workoutNotes = $0 }
                ),
                onSave: {
                    self.updateWorkoutNotes()
                    didConfirm = true
                },
                title: String(localized: "Finish Workout"),
                hint: nil,
                saveTitle: "Finish",
                onDidDismiss: {
                    guard didConfirm, !self.isDone else { return }
                    self.finishWorkout()
                }
            )
        )
    }
}
