//
//  ExerciseTrackerView+Notes.swift
//  Compound
//
//  The notes under the sets, each opening the note sheet on its own tab.
//

import SwiftUI

extension ExerciseTrackerView {

    func openNotes(on tab: NoteTab.Kind) {
        presenter.onNotePressed(
            for: delegate.exercise.wrappedValue,
            tab: tab,
            previousNote: delegate.previousNote,
            onSave: delegate.onUpdateNote,
            onSaveMesocycleNote: delegate.onUpdateMesocycleNote
        )
    }

    /// A note under the sets: its label, symbol and text, and the sheet tab that edits it (`nil`
    /// for one that cannot be edited here).
    struct ShownNote: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let symbol: String
        let text: String
        let tab: NoteTab.Kind?
    }

    /// One per note written: the mesocycle note (the plan's notes, read-only outside a mesocycle),
    /// the exercise note and this workout's.
    var shownNotes: [ShownNote] {
        let exercise = delegate.exercise.wrappedValue
        let canEditPlan = delegate.onUpdateMesocycleNote != nil
        return [
            presenter.planNotes(for: exercise).map {
                ShownNote(id: "plan", title: canEditPlan ? "Mesocycle Note" : "Plan Note", symbol: Symbol.pinnedNote, text: $0, tab: canEditPlan ? .mesocycle : nil)
            },
            presenter.note(for: exercise).map {
                ShownNote(id: "exercise", title: "Exercise Note", symbol: Symbol.pinnedNote, text: $0, tab: .exercise)
            },
            exercise.notes.map {
                ShownNote(id: "session", title: "Session Note", symbol: Symbol.note, text: $0, tab: .session)
            }
        ].compactMap { $0 }
    }

    /// The notes as cards, each opening the sheet on its own tab.
    var noteCards: some View {
        VStack(spacing: Spacing.s) {
            ForEach(shownNotes) { note in
                noteCard(note)
                    .accessibilityIdentifier(note.id == "plan" ? "ExerciseTracker.planNotes" : "")
            }
        }
    }

    /// A note set apart from anything the app says by its label, its symbol and a neutral fill
    /// rather than a tint. `tab` nil is a note that cannot be edited here.
    @ViewBuilder
    private func noteCard(_ note: ShownNote) -> some View {
        let (title, symbol, text, tab) = (note.title, note.symbol, note.text, note.tab)
        let content = VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text(title)
                    .font(.label)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: symbol)
                    .font(.label)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            // Three lines either way: an editable note opens whole in its sheet, so More, a
            // button inside the card's button, is only for one that cannot.
            Group {
                if tab == nil {
                    ClampedNote(text: text)
                } else {
                    Text(text).lineLimit(3)
                }
            }
            .font(.rowDetail)
            .foregroundStyle(Color.primary)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s)
        .background(Color.tintedSurface(.secondary), in: .rect(cornerRadius: Radius.s, style: .continuous))
        if let tab {
            Button {
                openNotes(on: tab)
            } label: {
                content.contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(title))
            .accessibilityValue(text)
            .accessibilityHint("Edits the note")
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(title))
                .accessibilityValue(text)
        }
    }
}

/// A note held to three lines under the sets, so a long one does not push the card off screen,
/// with More to read the rest in place. More shows only when the note is actually cut short.
private struct ClampedNote: View {
    let text: String
    var lineLimit = 3

    @State private var isExpanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var shownHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(text)
                .lineLimit(isExpanded ? nil : lineLimit)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shownHeight = $0 }
                // The whole note laid out at the same width and hidden, to tell whether the
                // line limit cuts it short.
                .background {
                    Text(text)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fullHeight = $0 }
                }
            if !isExpanded && fullHeight > shownHeight + 1 {
                Button("More") {
                    isExpanded = true
                }
                .fontWeight(.semibold)
                .buttonStyle(.borderless)
                // VoiceOver reads the whole note whatever its line limit.
                .accessibilityHidden(true)
            }
        }
    }
}
