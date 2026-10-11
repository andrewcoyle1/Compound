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

    /// What the note sheet's tabs are editing; committed only when the user saves.
    var draftNote = ""
    var draftExerciseNote = ""
    var draftMesocycleNote = ""

    init(
        interactor: ExerciseTrackerInteractor,
        router: ExerciseTrackerRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    /// The stored image, else the library's: a finished workout being corrected may predate it.
    func imageName(for exercise: WorkoutExerciseModel) -> String? {
        exercise.imageName(in: interactor.allExercises)
    }

    /// The exercise note: kept on the exercise and shown every time it is done, a cue for doing
    /// the lift ("bench at 30°", "left knee: go slow"). `nil` when there is nothing to say;
    /// whitespace only counts as nothing.
    func note(for exercise: WorkoutExerciseModel) -> String? {
        let trimmed = interactor.exerciseNote(for: exercise.templateId)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// The plan's notes for the exercise (the coach's cues), or `nil` when there are none. In a
    /// mesocycle workout they are the exercise's mesocycle note.
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

    /// Opens the note sheet on `tab`: this workout's note on the exercise (with last session's as
    /// a hint), the exercise note, and the mesocycle note when `onSaveMesocycleNote` is given.
    /// Each draft starts from the note already written, so reopening edits rather than replaces
    /// it, and Save writes only the notes that changed.
    func onNotePressed(
        for exercise: WorkoutExerciseModel,
        tab: NoteTab.Kind = .session,
        previousNote: String?,
        onSave: @escaping @MainActor (String) -> Void,
        onSaveMesocycleNote: (@MainActor (String) -> Void)? = nil
    ) {
        let session = exercise.notes ?? ""
        let pinned = note(for: exercise) ?? ""
        let mesocycle = exercise.planNotes ?? ""
        (draftNote, draftExerciseNote, draftMesocycleNote) = (session, pinned, mesocycle)
        var tabs = [
            NoteTab(
                kind: .session, title: String(localized: "Session"),
                text: Binding(get: { self.draftNote }, set: { self.draftNote = $0 }),
                hint: previousNote, footer: String(localized: "Saved with this workout in your history.")
            ),
            NoteTab(
                kind: .exercise, title: String(localized: "Exercise"),
                text: Binding(get: { self.draftExerciseNote }, set: { self.draftExerciseNote = $0 }),
                footer: String(localized: "Shown every time you do this exercise.")
            )
        ]
        if onSaveMesocycleNote != nil {
            tabs.append(NoteTab(
                kind: .mesocycle, title: String(localized: "Mesocycle"),
                text: Binding(get: { self.draftMesocycleNote }, set: { self.draftMesocycleNote = $0 }),
                footer: String(localized: "Shown every week on this day of your mesocycle.")
            ))
        }
        router.showWorkoutNotesView(
            delegate: WorkoutNotesDelegate(
                tabs: tabs,
                selectedTab: tabs.contains { $0.kind == tab } ? tab : .session,
                onSave: {
                    if self.draftNote != session { onSave(self.draftNote) }
                    if self.draftMesocycleNote != mesocycle { onSaveMesocycleNote?(self.draftMesocycleNote) }
                    if self.draftExerciseNote != pinned { self.saveExerciseNote(self.draftExerciseNote, for: exercise) }
                },
                title: exercise.name
            )
        )
    }

    private func saveExerciseNote(_ note: String, for exercise: WorkoutExerciseModel) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await interactor.setExerciseNote(trimmed.isEmpty ? nil : trimmed, for: exercise.templateId)
            } catch {
                router.showSimpleAlert(title: String(localized: "Unable to Save Note"), subtitle: error.localizedDescription)
            }
        }
    }
}
