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
}

struct ExerciseTrackerView<SetTracker: View>: View {

    @State var presenter: ExerciseTrackerPresenter
    let delegate: ExerciseTrackerDelegate

    @ScaledMetric(relativeTo: .body) private var thumbnailSide = ControlSize.thumbnail

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
                progressionNote: card.progressionNote,
                onProgressionNoteAcknowledged: card.onProgressionNoteAcknowledged,
                restTimer: card.restTimer,
                onLogSet: card.onLogSet,
                onCustomRestChanged: card.onCustomRestChanged
            )))
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

    /// The card's title row, then the user's own note. Kept short: the sets are the point.
    private func cardHeader(_ exercise: WorkoutExerciseModel, card: ExerciseCard, menu: AnyView) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .top, spacing: Spacing.m) {
                ExerciseImageView(name: exercise.name, imageName: presenter.imageName(for: exercise))
                    .frame(width: thumbnailSide, height: thumbnailSide)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    // The menu sits on the name's line, so it reads as the exercise's own.
                    HStack(alignment: .center, spacing: Spacing.s) {
                        Text(exercise.name)
                            .font(.sectionTitle)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 0)
                        menu
                    }
                    if let label = delegate.supersetLabel {
                        Chip(label, systemImage: Symbol.superset, tint: .superset)
                    }
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

    @State private var isExpanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var shownHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(text)
                .lineLimit(isExpanded ? nil : 3)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shownHeight = $0 }
                // The whole note laid out at the same width and hidden, to tell whether three
                // lines cut it short.
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
