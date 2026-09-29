//
//  ExerciseTrackerPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 02/03/2026.
//

import SwiftUI

@Observable
@MainActor
class ExerciseTrackerPresenter {
    private let interactor: ExerciseTrackerInteractor
    private let router: ExerciseTrackerRouter

    /// What the note sheet is editing; committed only when the user saves.
    var draftNote = ""
    
    init(
        interactor: ExerciseTrackerInteractor,
        router: ExerciseTrackerRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    /// The note the user keeps on this exercise, ready to draw — or `nil` when there is nothing
    /// to say.
    ///
    /// Written on the exercise's settings screen and, until now, read only back there. It is a
    /// cue for doing the lift ("bench at 30°", "left knee: go slow"), so the place it is worth
    /// having is the tracker, while the lift is being done.
    ///
    /// Whitespace only counts as nothing: a note saved as a stray newline should leave the header
    /// exactly as it was.
    func note(for exercise: WorkoutExerciseModel) -> String? {
        let trimmed = interactor.exerciseNote(for: exercise.templateId)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Opens the note sheet for this session's note on the exercise, with last session's as a
    /// hint. The draft starts from the note already written, so reopening edits rather than
    /// replaces it.
    func onNotePressed(
        for exercise: WorkoutExerciseModel,
        previousNote: String?,
        onSave: @escaping @MainActor (String) -> Void
    ) {
        draftNote = exercise.notes ?? ""
        router.showWorkoutNotesView(
            delegate: WorkoutNotesDelegate(
                notes: Binding(
                    get: { self.draftNote },
                    set: { self.draftNote = $0 }
                ),
                onSave: { onSave(self.draftNote) },
                title: exercise.name,
                hint: previousNote
            )
        )
    }
}
