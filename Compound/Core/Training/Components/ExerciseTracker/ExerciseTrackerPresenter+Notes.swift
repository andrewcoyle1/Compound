//
//  ExerciseTrackerPresenter+Notes.swift
//  Compound
//
//  The exercise's notes and its sheet, the plan's video link, and its picture.
//

import SwiftUI

extension ExerciseTrackerPresenter {

    /// The stored image, else the library's: a finished workout being corrected may predate it.
    func imageName(for exercise: WorkoutExerciseModel) -> String? {
        exercise.imageName(in: interactor.allExercises)
    }

    /// The exercise note: kept on the exercise and shown every time it is done, a cue for doing
    /// the lift ("bench at 30°", "left knee: go slow"). `nil` when there is nothing to say;
    /// whitespace only counts as nothing.
    func note(for exercise: WorkoutExerciseModel) -> String? {
        Self.trimmed(interactor.exerciseNote(for: exercise.templateId))
    }

    /// The plan's notes for the exercise (the coach's cues), or `nil` when there are none. In a
    /// mesocycle workout they are the exercise's mesocycle note.
    func planNotes(for exercise: WorkoutExerciseModel) -> String? {
        Self.trimmed(exercise.planNotes)
    }

    /// `text` without its surrounding whitespace, or `nil` when nothing is left.
    private static func trimmed(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
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
        interactor.trackEvent(event: Event.notesOpened(tab: "\(tab)"))
        let session = exercise.notes ?? ""
        let pinned = note(for: exercise) ?? ""
        let mesocycle = exercise.planNotes ?? ""
        (sessionNoteDraft, exerciseNoteDraft, mesocycleNoteDraft) = (session, pinned, mesocycle)
        var tabs = [
            NoteTab(
                kind: .session, title: String(localized: "Session"),
                text: Binding(get: { self.sessionNoteDraft }, set: { self.sessionNoteDraft = $0 }),
                hint: previousNote, footer: String(localized: "Saved with this workout in your history.")
            ),
            NoteTab(
                kind: .exercise, title: String(localized: "Exercise"),
                text: Binding(get: { self.exerciseNoteDraft }, set: { self.exerciseNoteDraft = $0 }),
                footer: String(localized: "Shown every time you do this exercise.")
            )
        ]
        if onSaveMesocycleNote != nil {
            tabs.append(NoteTab(
                kind: .mesocycle, title: String(localized: "Mesocycle"),
                text: Binding(get: { self.mesocycleNoteDraft }, set: { self.mesocycleNoteDraft = $0 }),
                footer: String(localized: "Shown every week on this day of your mesocycle.")
            ))
        }
        router.showWorkoutNotesView(
            delegate: WorkoutNotesDelegate(
                tabs: tabs,
                selectedTab: tabs.contains { $0.kind == tab } ? tab : .session,
                onSave: {
                    if self.sessionNoteDraft != session { onSave(self.sessionNoteDraft) }
                    if self.mesocycleNoteDraft != mesocycle { onSaveMesocycleNote?(self.mesocycleNoteDraft) }
                    if self.exerciseNoteDraft != pinned { self.saveExerciseNote(self.exerciseNoteDraft, for: exercise) }
                },
                title: exercise.name
            )
        )
    }

    private func saveExerciseNote(_ note: String, for exercise: WorkoutExerciseModel) {
        Task {
            do {
                try await interactor.setExerciseNote(Self.trimmed(note), for: exercise.templateId)
                interactor.playHaptic(option: .success)
                interactor.trackEvent(event: Event.exerciseNoteSaved)
            } catch {
                interactor.playHaptic(option: .error)
                interactor.trackEvent(event: Event.exerciseNoteSaveFail(error: error))
                router.showSimpleAlert(title: String(localized: "Unable to Save Note"), subtitle: error.localizedDescription)
            }
        }
    }
}
