//
//  NoteCard.swift
//  Compound
//
//  A note under the sets.
//

import SwiftUI

/// A note on the card: its label, symbol and text, and the sheet tab that edits it.
struct CardNote: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let symbol: String
    let text: String
    /// `nil` for a note that cannot be edited here, as the plan's outside a mesocycle.
    let tab: NoteTab.Kind?
}

/// A note set apart from anything the app says by its label, its symbol and a neutral fill rather
/// than a tint. An editable one opens its sheet on a tap (`onEdit`); one that cannot be edited
/// reads in place, with More for the rest.
struct NoteCard: View {

    let note: CardNote
    var onEdit: (() -> Void)?

    var body: some View {
        if let onEdit {
            Button(action: onEdit) {
                content.contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(note.title))
            .accessibilityValue(note.text)
            .accessibilityHint("Edits the note")
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(note.title))
                .accessibilityValue(note.text)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text(note.title)
                    .font(.label)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: note.symbol)
                    .font(.label)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            // Three lines either way: an editable note opens whole in its sheet, so More, a
            // button inside the card's button, is only for one that cannot.
            Group {
                if onEdit == nil {
                    ClampedNote(text: note.text)
                } else {
                    Text(note.text).lineLimit(3)
                }
            }
            .font(.rowDetail)
            .foregroundStyle(Color.primary)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s)
        .background(Color.tintedSurface(.secondary), in: .rect(cornerRadius: Radius.s, style: .continuous))
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
