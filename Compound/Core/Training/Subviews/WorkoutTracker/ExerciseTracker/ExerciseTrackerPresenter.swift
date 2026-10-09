//
//  ExerciseTrackerPresenter.swift
//  Compound
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
    /// The stored image, else the library's: a finished workout being corrected may predate it.
    func imageName(for exercise: WorkoutExerciseModel) -> String? {
        exercise.imageName(in: interactor.allExercises)
    }

    func note(for exercise: WorkoutExerciseModel) -> String? {
        let trimmed = interactor.exerciseNote(for: exercise.templateId)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// The plan's notes for the exercise (the coach's cues), or `nil` when there are none.
    func planNotes(for exercise: WorkoutExerciseModel) -> String? {
        let trimmed = exercise.planNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// The plan's video link, when it is a web address to open in the browser. Anything else, a
    /// typo or another scheme, hides Watch rather than offering a link that goes nowhere.
    func watchURL(for exercise: WorkoutExerciseModel) -> URL? {
        guard let text = exercise.linkURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host()?.isEmpty == false
        else { return nil }
        return url
    }

    func onWatchPressed(_ url: URL, open: OpenURLAction) {
        interactor.trackEvent(event: Event.watchPressed)
        open(url)
    }

    enum Event: LoggableEvent {
        case watchPressed

        var eventName: String {
            switch self {
            case .watchPressed: return "ExerciseTracker_Watch_Pressed"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
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
