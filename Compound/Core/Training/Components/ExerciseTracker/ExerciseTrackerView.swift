//
//  ExerciseTrackerView.swift
//  Compound
//
//
//

import SwiftUI

struct ExerciseTrackerDelegate {
    let exercise: Binding<WorkoutExerciseModel>
    let lastExercise: WorkoutExerciseModel?
    var isExpanded: Binding<Bool> = .constant(false)
    var allWorkoutExercises: [WorkoutExerciseModel] = []
    /// What the engine suggests for this exercise's working sets, shown by the Auto column.
    var progressionSuggestion: ProgressionSuggestion?
    /// The note this exercise was left with last session, shown as a hint when writing this one.
    var previousNote: String?
    var onSetSupersetGroup: @MainActor (String, String?) -> Void = { _, _ in }
    var onDeleteExercise: @MainActor () -> Void = { }
    /// Saves this session's note on the exercise; an empty string clears it.
    var onUpdateNote: @MainActor (String) -> Void = { _ in }
    /// Saves the exercise's mesocycle note; `nil` when it has none to edit, outside a mesocycle.
    var onUpdateMesocycleNote: (@MainActor (String) -> Void)?
    /// See `SetTrackerDelegate.onSwap`.
    var onSwap: (@MainActor (ExerciseModel) -> Void)?
    /// The live tracker draws the current exercise as an open card. `nil` is the collapsible row
    /// a finished workout's editor uses.
    var card: ExerciseCard?
}

/// What the live tracker's exercise card shows beyond the sets.
struct ExerciseCard {
    /// Why smart progression changed today's numbers, as a row above the sets until it is tapped.
    var progressionNote: String?
    var onProgressionNoteAcknowledged: @MainActor () -> Void = { }
    var restTimer: InlineRestTimer?
    /// Moves the exercise to the end of the workout; `nil` when there is nothing to put it behind.
    var onDoLater: (@MainActor () -> Void)?
    /// See `SetTrackerRowDelegate.onLogSet` and `onCustomRestChanged`.
    var onLogSet: (@MainActor (String, Int?) -> Void)?
    var onCustomRestChanged: (@MainActor (String, Int?) -> Void)?
    /// One piece of the table rather than all of it, for a superset's card to place among its
    /// partners' rows. `nil` draws the whole table.
    var piece: SetTrackerPiece?
    /// The member's letter on a superset's card ("A", "B"), which its header shows in place of the
    /// superset's own label: the member header.
    var memberLetter: String?
    /// The bodyweight the movement lifts, while the setting is on: the header's badge and the rows'
    /// "BW" labels. `nil` leaves the card as it was.
    var bodyweight: BodyweightContribution?
    /// Off while the exercise strip shows thumbnails: the strip already pictures the exercise.
    var showsImage = true
}

struct ExerciseTrackerView<SetTracker: View>: View {

    @State var presenter: ExerciseTrackerPresenter
    let delegate: ExerciseTrackerDelegate

    @ScaledMetric(relativeTo: .body) private var thumbnailSide = ControlSize.thumbnail
    @Environment(\.openURL) private var openURL

    @ViewBuilder var setTracker: (SetTrackerDelegate) -> SetTracker

    var body: some View {
        if let card = delegate.card {
            setTracker(setDelegate(card: SetTrackerCard(
                header: { menu in AnyView(cardHeader(delegate.exercise.wrappedValue, card: card, menu: menu)) },
                notes: hasNotes(delegate.exercise.wrappedValue) ? AnyView(noteCards(delegate.exercise.wrappedValue)) : nil,
                onNotePressed: { openNotes(on: .session) },
                onWatch: watchAction(for: delegate.exercise.wrappedValue),
                exerciseCard: card
            )))
            .environment(\.showsBodyweightLoad, card.bodyweight != nil)
        } else {
            DisclosureGroup(isExpanded: delegate.isExpanded) {
                setTracker(setDelegate(card: nil))
            } label: {
                exerciseHeader(delegate.exercise.wrappedValue)
            }
        }
    }

    private func openNotes(on tab: NoteTab.Kind) {
        presenter.onNotePressed(
            for: delegate.exercise.wrappedValue,
            tab: tab,
            previousNote: delegate.previousNote,
            onSave: delegate.onUpdateNote,
            onSaveMesocycleNote: delegate.onUpdateMesocycleNote
        )
    }

    private func setDelegate(card: SetTrackerCard?) -> SetTrackerDelegate {
        SetTrackerDelegate(
            exercise: delegate.exercise,
            lastExercise: delegate.lastExercise,
            progressionSuggestion: delegate.progressionSuggestion,
            allWorkoutExercises: delegate.allWorkoutExercises,
            onSetSupersetGroup: delegate.onSetSupersetGroup,
            onDeleteExercise: delegate.onDeleteExercise,
            onSwap: delegate.onSwap,
            card: card
        )
    }

    // MARK: - Card

    /// Watch in the card's menu, when the plan links a video the browser can open.
    private func watchAction(for exercise: WorkoutExerciseModel) -> (@MainActor () -> Void)? {
        guard let url = presenter.watchURL(for: exercise) else { return nil }
        return { presenter.onWatchPressed(url, open: openURL) }
    }

    /// The card's title row. Kept short: the sets are the point, and the notes follow them.
    private func cardHeader(_ exercise: WorkoutExerciseModel, card: ExerciseCard, menu: AnyView) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .top, spacing: Spacing.m) {
                if card.showsImage {
                    ExerciseImageView(name: exercise.name, imageName: presenter.imageName(for: exercise))
                        .frame(width: thumbnailSide, height: thumbnailSide)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    if let bodyweight = card.bodyweight, bodyweight.contributionKg != nil {
                        // The badge sits before the menu, and goes under the name when the line
                        // cannot hold both, as at accessibility sizes.
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: Spacing.s) {
                                cardTitle(exercise, card: card)
                                Spacer(minLength: 0)
                                BodyweightContributionBadge(contribution: bodyweight)
                                menu
                            }
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                HStack(alignment: .center, spacing: Spacing.s) {
                                    cardTitle(exercise, card: card)
                                    Spacer(minLength: 0)
                                    menu
                                }
                                BodyweightContributionBadge(contribution: bodyweight)
                            }
                        }
                    } else {
                        // The menu sits on the name's line, so it reads as the exercise's own.
                        HStack(alignment: .center, spacing: Spacing.s) {
                            cardTitle(exercise, card: card)
                            Spacer(minLength: 0)
                            menu
                        }
                    }
                }

            }
        }
        .padding(.vertical, Spacing.s)
    }

    /// Whether any note is written, so an exercise without one gets no empty row under its sets.
    private func hasNotes(_ exercise: WorkoutExerciseModel) -> Bool {
        presenter.planNotes(for: exercise) != nil || presenter.note(for: exercise) != nil || exercise.notes != nil
    }

    /// Under the sets, one card per note written: the mesocycle note (the plan's notes, read-only
    /// outside a mesocycle), the exercise note and this workout's. Each opens the sheet on its tab.
    @ViewBuilder
    private func noteCards(_ exercise: WorkoutExerciseModel) -> some View {
        let canEditPlan = delegate.onUpdateMesocycleNote != nil
        VStack(spacing: Spacing.s) {
            if let plan = presenter.planNotes(for: exercise) {
                noteCard(canEditPlan ? "Mesocycle Note" : "Plan Note", symbol: Symbol.pinnedNote, text: plan, tab: canEditPlan ? .mesocycle : nil)
                    .accessibilityIdentifier("ExerciseTracker.planNotes")
            }
            if let note = presenter.note(for: exercise) {
                noteCard("Exercise Note", symbol: Symbol.pinnedNote, text: note, tab: .exercise)
            }
            if let note = exercise.notes {
                noteCard("Session Note", symbol: Symbol.note, text: note, tab: .session)
            }
        }
    }

    /// A note set apart from anything the app says by its label, its symbol and a neutral fill
    /// rather than a tint. `tab` nil is a note that cannot be edited here.
    @ViewBuilder
    private func noteCard(_ title: LocalizedStringKey, symbol: String, text: String, tab: NoteTab.Kind?) -> some View {
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

    /// The member header's letter, when the card is a superset member's, then the name.
    @ViewBuilder
    private func cardTitle(_ exercise: WorkoutExerciseModel, card: ExerciseCard) -> some View {
        if let letter = card.memberLetter {
            Chip(letter, systemImage: Symbol.superset, tint: .superset)
                .accessibilityLabel(String(localized: "Superset member \(letter)"))
        }
        Text(exercise.name)
            .font(.sectionTitle)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    func exerciseHeader(_ exercise: WorkoutExerciseModel) -> some View {
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                if let sessionNote = exercise.notes {
                    Label(sessionNote, systemImage: Symbol.note)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            noteButton(exercise)
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
        .font(.caption)
        .foregroundStyle(isDone ? AnyShapeStyle(.success) : AnyShapeStyle(.secondary))
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? String(localized: "All sets done") : "")
    }

    /// Borderless so a tap opens the note sheet rather than toggling the card it sits on.
    private func noteButton(_ exercise: WorkoutExerciseModel) -> some View {
        Button {
            presenter.onNotePressed(
                for: exercise,
                previousNote: delegate.previousNote,
                onSave: delegate.onUpdateNote
            )
        } label: {
            Image(systemName: exercise.notes == nil ? Symbol.note + ".badge.plus" : Symbol.note)
                .tapTarget()
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(exercise.notes == nil ? String(localized: "Add note") : String(localized: "Edit note"))
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

#Preview {
    @Previewable @State var exercise: WorkoutExerciseModel = WorkoutExerciseModel.mock
    @Previewable @State var session: WorkoutSessionModel = WorkoutSessionModel.mock
    let lastExercise: WorkoutExerciseModel = .mock
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = ExerciseTrackerDelegate(exercise: $exercise, lastExercise: lastExercise)

    RouterView { router in
        builder.exerciseTrackerView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    func exerciseTrackerView(
        router: AnyRouter,
        delegate: ExerciseTrackerDelegate
    ) -> some View {
        ExerciseTrackerView(
            presenter: ExerciseTrackerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            setTracker: { delegate in
                self.setTrackerView(router: router, delegate: delegate)
            }
        )
    }
}
