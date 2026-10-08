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
    var supersetLabel: String?
    /// The one line smart progression has to say about this exercise, if anything.
    /// What the engine suggests for this exercise's working sets, shown by the Auto column.
    var progressionSuggestion: ProgressionSuggestion?
    /// The note this exercise was left with last session, shown as a hint when writing this one.
    var previousNote: String?
    var onSetSupersetGroup: @MainActor (String, String?) -> Void = { _, _ in }
    var onDeleteExercise: @MainActor () -> Void = { }
    /// Called with the set that was just logged, so the screen can re-suggest what is left.
    var onSetCompleted: @MainActor (WorkoutSetModel, WorkoutExerciseModel) -> Void = { _, _ in }
    /// Saves this session's note on the exercise; an empty string clears it.
    var onUpdateNote: @MainActor (String) -> Void = { _ in }
    /// See `SetTrackerDelegate.onSwap`.
    var onSwap: (@MainActor (ExerciseModel) -> Void)?
    /// The live tracker draws the current exercise as an open card. `nil` is the collapsible row
    /// a finished workout's editor uses.
    var card: ExerciseCard?
}

/// What the live tracker's exercise card shows beyond the sets.
struct ExerciseCard {
    /// See `SetTrackerCard.progressionNote`.
    var progressionNote: String?
    var onProgressionNoteAcknowledged: @MainActor () -> Void = { }
    var restTimer: InlineRestTimer?
    var onDoLater: (@MainActor () -> Void)?
    var onLogSet: (@MainActor (String, Int?) -> Void)?
    var onCustomRestChanged: (@MainActor (String, Int?) -> Void)?
    /// See `SetTrackerCard.correction`, `onCorrection` and `onUndoManager`.
    var correction: SetCorrection?
    var onCorrection: (@MainActor (String, SetCorrectionAction) -> Void)?
    var onUndoManager: (@MainActor (UndoManager?) -> Void)?
    /// See `SetTrackerCard.piece` and `showAutoRanges`.
    var piece: SetTrackerPiece?
    var showAutoRanges: Bool?
    /// The member's letter on a superset's card ("A", "B"), which its header shows in place of the
    /// superset's own label: the member header.
    var memberLetter: String?
    /// The bodyweight the movement lifts, while the setting is on: the header's badge and the rows'
    /// "BW" labels. `nil` leaves the card as it was.
    var bodyweight: BodyweightContribution?
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
                hasNote: delegate.exercise.wrappedValue.notes != nil,
                onNotePressed: {
                    presenter.onNotePressed(
                        for: delegate.exercise.wrappedValue,
                        previousNote: delegate.previousNote,
                        onSave: delegate.onUpdateNote
                    )
                },
                onDoLater: card.onDoLater,
                onWatch: watchAction(for: delegate.exercise.wrappedValue),
                progressionNote: card.progressionNote,
                onProgressionNoteAcknowledged: card.onProgressionNoteAcknowledged,
                restTimer: card.restTimer,
                onLogSet: card.onLogSet,
                onCustomRestChanged: card.onCustomRestChanged,
                correction: card.correction,
                onCorrection: card.onCorrection,
                onUndoManager: card.onUndoManager,
                piece: card.piece,
                showAutoRanges: card.showAutoRanges
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

    private func setDelegate(card: SetTrackerCard?) -> SetTrackerDelegate {
        SetTrackerDelegate(
            exercise: delegate.exercise,
            lastExercise: delegate.lastExercise,
            progressionSuggestion: delegate.progressionSuggestion,
            allWorkoutExercises: delegate.allWorkoutExercises,
            onSetSupersetGroup: delegate.onSetSupersetGroup,
            onDeleteExercise: delegate.onDeleteExercise,
            onSetCompleted: delegate.onSetCompleted,
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

    /// The card's title row, then the user's own note. Kept short: the sets are the point.
    private func cardHeader(_ exercise: WorkoutExerciseModel, card: ExerciseCard, menu: AnyView) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .top, spacing: Spacing.m) {
                ExerciseImageView(name: exercise.name, imageName: presenter.imageName(for: exercise))
                    .frame(width: thumbnailSide, height: thumbnailSide)
                    .accessibilityHidden(true)

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
                    underTitle(exercise, card: card)
                }

            }

            if let note = presenter.note(for: exercise) {
                pinnedNote(note)
            }

            if let sessionNote = exercise.notes {
                Label {
                    ClampedNote(text: sessionNote)
                } icon: {
                    Image(systemName: Symbol.note)
                }
                .font(.rowDetail)
            }

        }
        .padding(.vertical, Spacing.s)
    }

    /// Under the name: the superset's label, unless the card is a member's, then the plan's cues
    /// for the lift, held to two lines.
    @ViewBuilder
    private func underTitle(_ exercise: WorkoutExerciseModel, card: ExerciseCard) -> some View {
        if card.memberLetter == nil, let label = delegate.supersetLabel {
            Chip(label, systemImage: Symbol.superset, tint: .superset)
        }
        if let notes = presenter.planNotes(for: exercise) {
            planNotesView(notes)
        }
    }

    private func planNotesView(_ notes: String) -> some View {
        ClampedNote(text: notes, lineLimit: 2)
            .font(.rowDetail)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Plan notes")
            .accessibilityValue(notes)
            .accessibilityIdentifier("ExerciseTracker.planNotes")
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

    /// The note the user keeps on the exercise, set apart from anything the app says by its
    /// label, its pin and a neutral fill rather than a tint.
    private func pinnedNote(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Label("Your note", systemImage: Symbol.pinnedNote)
                .font(.label)
                .foregroundStyle(.secondary)
            ClampedNote(text: note)
                .font(.rowDetail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s)
        .background(Color.tintedSurface(.secondary), in: .rect(cornerRadius: Radius.s, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    func exerciseHeader(_ exercise: WorkoutExerciseModel) -> some View {
        HStack(alignment: .center) {
            ExerciseImageView(name: exercise.name, imageName: presenter.imageName(for: exercise))
                .frame(width: thumbnailSide, height: thumbnailSide)
                .clipShape(.rect(cornerRadius: Radius.s, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.s) {
                    Text(exercise.name)
                        .font(.sectionTitle)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    if let label = delegate.supersetLabel {
                        Chip(label, systemImage: Symbol.superset, tint: .superset)
                    }
                }

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

/// A note held to three lines above the sets, so a long one does not push the table off screen,
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
        delegate: ExerciseTrackerDelegate,
        onStartRest: ((Int) -> Void)? = nil
    ) -> some View {
        ExerciseTrackerView(
            presenter: ExerciseTrackerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            setTracker: { delegate in
                self.setTrackerView(
                    router: router,
                    delegate: delegate,
                    onStartRest: onStartRest
                )
            }
        )
    }
}
