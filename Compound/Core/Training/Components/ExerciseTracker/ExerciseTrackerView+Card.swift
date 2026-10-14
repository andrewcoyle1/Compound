//
//  ExerciseTrackerView+Card.swift
//  Compound
//
//  The exercise's title: the live card's header with its menu, or the finished workout editor's
//  row that opens onto the sets.
//

import SwiftUI

extension ExerciseTrackerView {

    /// Watch in the card's menu, when the plan links a video the browser can open.
    var watchAction: (@MainActor () -> Void)? {
        guard let url = presenter.watchURL(for: delegate.exercise.wrappedValue) else { return nil }
        return { presenter.onWatchPressed(url, open: openURL) }
    }

    /// The card's title row, in the primary colour a section header would otherwise grey. Kept
    /// short: the sets are the point, and the notes follow them.
    func cardHeader(_ card: ExerciseCard) -> some View {
        let exercise = delegate.exercise.wrappedValue
        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            if let bodyweight = card.bodyweight, bodyweight.contributionKg != nil {
                // The badge sits before the menu, and goes under the name when the line
                // cannot hold both, as at accessibility sizes.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: Spacing.s) {
                        cardTitle(exercise, card: card)
                        Spacer(minLength: 0)
                        BodyweightContributionBadge(contribution: bodyweight)
                        menu(card)
                    }
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(alignment: .center, spacing: Spacing.s) {
                            cardTitle(exercise, card: card)
                            Spacer(minLength: 0)
                            menu(card)
                        }
                        BodyweightContributionBadge(contribution: bodyweight)
                    }
                }
            } else {
                // The menu sits on the name's line, so it reads as the exercise's own.
                HStack(alignment: .center, spacing: Spacing.s) {
                    cardTitle(exercise, card: card)
                    Spacer(minLength: 0)
                    menu(card)
                }
            }
        }
        .padding(.vertical, Spacing.s)
        .foregroundStyle(.primary)
        .textCase(nil)
    }

    /// The card's menu; a superset member's actions are a submenu of the superset's one menu.
    @ViewBuilder
    private func menu(_ card: ExerciseCard) -> some View {
        if card.memberLabel == nil {
            actionsMenu
        }
    }

    /// The member header's letter, when the card is a superset member's, then the name.
    @ViewBuilder
    private func cardTitle(_ exercise: WorkoutExerciseModel, card: ExerciseCard) -> some View {
        if let label = card.memberLabel {
            Chip(label, systemImage: Symbol.superset, tint: .superset)
                .accessibilityLabel(String(localized: "Superset member \(label)"))
        }
        // Under the superset's own title a member's name is a row's, not a section's.
        Text(exercise.name)
            .font(card.memberLabel == nil ? .sectionTitle : .rowTitle)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    var exerciseHeader: some View {
        let exercise = delegate.exercise.wrappedValue
        HStack(alignment: .center) {
            ExerciseImageView(name: exercise.name, imageName: presenter.imageName(for: exercise))
                .frame(width: thumbnailSide, height: thumbnailSide)
                .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(exercise.name)
                    .font(.sectionTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                setProgress(exercise)

                if let note = presenter.note(for: exercise) {
                    Text(note)
                        .font(.label)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                if let sessionNote = exercise.notes {
                    Label(sessionNote, systemImage: Symbol.note)
                        .font(.label)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            noteButton
        }
        .tappableBackground()
        .listRowInsets(.vertical, .zero)
    }

    /// Counted in sets, not rows: three sets a side reads "Set 2/3", not "Set 4/6". A finished
    /// exercise gets a check as well as the colour.
    private func setProgress(_ exercise: WorkoutExerciseModel) -> some View {
        let isDone = exercise.loggedSetCount == exercise.workingSetCount
        return HStack(spacing: Spacing.xs) {
            if isDone {
                Image(systemName: Symbol.success)
                    .accessibilityHidden(true)
            }
            Text("Set \(min(exercise.loggedSetCount + 1, exercise.workingSetCount))/\(exercise.workingSetCount)")
        }
        .font(.label)
        .foregroundStyle(isDone ? AnyShapeStyle(.success) : AnyShapeStyle(.secondary))
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? String(localized: "All sets done") : "")
    }

    /// Borderless so a tap opens the note sheet rather than toggling the card it sits on.
    private var noteButton: some View {
        let exercise = delegate.exercise.wrappedValue
        return Button {
            openNotes(on: .session)
        } label: {
            Image(systemName: exercise.notes == nil ? Symbol.addNote : Symbol.note)
                .tapTarget()
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(exercise.notes == nil ? String(localized: "Add note") : String(localized: "Edit note"))
    }
}
