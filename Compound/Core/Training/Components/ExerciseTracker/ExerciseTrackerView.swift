//
//  ExerciseTrackerView.swift
//  Compound
//
//  One exercise's set table: column headings, the rows, Add Set and the notes. On the live
//  tracker it is the card's section, or one piece of a superset's card (`ExerciseTrackerPiece`);
//  in a finished workout's editor, a row that opens onto it.
//

import SwiftUI

struct ExerciseTrackerView<SetTrackerRow: View>: View {

    @State var presenter: ExerciseTrackerPresenter
    let delegate: ExerciseTrackerDelegate

    @ViewBuilder var setTrackerRow: (SetTrackerRowDelegate) -> SetTrackerRow

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    /// The sets' circle (`SetTrackerRowView.setCircleSide`).
    @ScaledMetric(relativeTo: .caption) private var addSetCircleSide: CGFloat = ControlSize.thumbnail - Spacing.xs
    @ScaledMetric(relativeTo: .body) var thumbnailSide = ControlSize.thumbnail
    @Environment(\.openURL) var openURL

    /// Last or Auto, kept on the device. Read here rather than once per presenter, so a switch in
    /// one superset member's headings reaches every member's rows.
    @AppStorage(ExerciseTrackerPresenter.showAutoRangesKey) var showAutoRanges = false

    /// Whether the logged warm-ups are shown row by row rather than as one line.
    @State private var showsLoggedWarmups = false

    /// The rows stack into two lines at accessibility sizes; the headers follow them.
    var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        if let card = delegate.card {
            Group {
                if let piece = card.piece {
                    pieceView(piece)
                } else {
                    Section {
                        tableBody
                    } header: {
                        cardHeader(card)
                    }
                    .listSectionMargins(.top, Spacing.s)
                }
            }
            .environment(\.showsBodyweightLoad, card.bodyweight != nil)
        } else {
            DisclosureGroup(isExpanded: delegate.isExpanded) {
                tableBody
            } label: {
                exerciseHeader
            }
        }
    }

    @ViewBuilder
    private var tableBody: some View {
        // The table runs to the card's edge.
        progressionNoteRow
        Group {
            VStack {
                if delegate.card == nil {
                    actionBar
                }
                columnHeaders(setLabel: nil)
            }
            loggedWarmupsGroup
            // Under the folded warm-ups, so a rest after the last warm-up follows it.
            if let timer = delegate.card?.restTimer, timer.anchor == .top {
                InlineRestTimerRow(timer: timer)
            }
            ForEach(delegate.exercise.wrappedValue.sets.filter { !$0.isWarmup || $0.completedAt == nil }) { set in
                row(for: set)
                restRow(below: set)
            }
            addSetButton
        }
        .setTableRow()
        .listSectionMargins(.top, 0)
        notesRow
    }

    /// Why smart progression changed today's numbers, above the sets until it is tapped.
    @ViewBuilder
    private var progressionNoteRow: some View {
        if let card = delegate.card, let note = card.progressionNote {
            ProgressionNote(text: note, onAcknowledge: card.onProgressionNoteAcknowledged)
                .listRowSeparator(.hidden)
        }
    }

    /// The notes under the add-set button, with the list's own insets like the title row.
    @ViewBuilder
    private var notesRow: some View {
        if delegate.card != nil, !shownNotes.isEmpty {
            noteCards
                .listRowSeparator(.hidden)
        }
    }

    /// Done warm-ups fold into one line, so the table starts at the work, and open on a tap to be
    /// corrected.
    @ViewBuilder
    private var loggedWarmupsGroup: some View {
        let loggedWarmups = delegate.exercise.wrappedValue.sets.filter { $0.isWarmup && $0.completedAt != nil }
        if !loggedWarmups.isEmpty {
            DisclosureGroup(isExpanded: $showsLoggedWarmups) {
                ForEach(loggedWarmups) { set in
                    row(for: set)
                }
            } label: {
                Label {
                    Text("\(loggedWarmups.count) warm-ups")
                } icon: {
                    Image(systemName: Symbol.success)
                        .foregroundStyle(.success)
                }
                .font(.rowDetail)
                .frame(minHeight: ControlSize.row)
                .padding(.leading, Spacing.l)
            }
        }
    }

    private func row(
        for set: WorkoutSetModel,
        badge: String? = nil,
        isNext: Bool? = nil,
        separators: (top: Visibility, bottom: Visibility) = (.visible, .visible)
    ) -> some View {
        let exercise = delegate.exercise.wrappedValue
        // The editor has no current row; a superset's card marks only the set it logs next.
        let rowState: SetRowState? = if delegate.card == nil {
            nil
        } else if let isNext {
            ActiveWorkout.blockRowState(of: set, in: exercise, isNext: isNext)
        } else {
            ActiveWorkout.rowState(of: set, in: exercise)
        }
        // Matched on the side as well as the number: a left set inheriting the right arm's last
        // weight sends the user chasing the other arm's numbers. A drop is matched on its kind,
        // and has no suggestion of its own: its parent's would fill it with the heavier figures.
        return setTrackerRow(
            SetTrackerRowDelegate(
                exercise: delegate.exercise,
                set: setBinding(for: set),
                lastSet: ActiveWorkout.lastSet(for: set, in: exercise, last: delegate.lastExercise),
                progressionSuggestion: set.isSubSet ? nil : delegate.progressionSuggestion?.suggestedSet(for: set, in: exercise),
                showAutoRanges: showAutoRanges,
                rowState: rowState,
                onLogSet: delegate.card?.onLogSet,
                onCustomRestChanged: delegate.card?.onCustomRestChanged,
                customRestSeconds: delegate.card?.customRestSeconds[set.id],
                badgeLabel: badge
            )
        )
        .listRowSeparator(separators.top, edges: .top)
        .listRowSeparator(separators.bottom, edges: .bottom)
    }

    /// The set by id, not by position, as `WorkoutTrackerView.currentExerciseSection` binds the
    /// exercise. A binding by index read `sets[4]` of four sets when an earlier set was deleted
    /// with the keyboard open on the last, and trapped. Once the set is gone the getter hands back
    /// what it last held, and the setter has nothing to write.
    private func setBinding(for set: WorkoutSetModel) -> Binding<WorkoutSetModel> {
        let exercise = delegate.exercise
        let id = set.id
        return Binding(
            get: { exercise.wrappedValue.sets.first { $0.id == id } ?? set },
            set: { updated in
                guard let index = exercise.wrappedValue.sets.firstIndex(where: { $0.id == id }) else { return }
                exercise.wrappedValue.sets[index] = updated
            }
        )
    }

    /// Under the set just logged: the rest it started. Correcting the set is the bar over the
    /// log button (`WorkoutTrackerPresenter.restCorrection`).
    @ViewBuilder
    private func restRow(below set: WorkoutSetModel) -> some View {
        if let timer = delegate.card?.restTimer, timer.anchor == .below(setId: set.id) {
            InlineRestTimerRow(timer: timer)
        }
    }

    private var addSetButton: some View {
        Button {
            presenter.addSet(exercise: delegate.exercise)
        } label: {
            // A circle in the Set column, as the sets' own are.
            Image(systemName: Symbol.add)
                .font(.label.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: addSetCircleSide, height: addSetCircleSide)
                .background(Color.tintedSurface(.secondary), in: .circle)
                .overlay {
                    if colorSchemeContrast == .increased {
                        Circle().strokeBorder(.secondary, lineWidth: 1)
                    }
                }
                .frame(minWidth: SetTrackerRowView.setColumnWidth, minHeight: ControlSize.row)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        // On a superset's card each member has its own, so each says whose it is.
        .accessibilityLabel(delegate.card?.piece == nil ? String(localized: "Add Set") : String(localized: "Add Set to \(delegate.exercise.wrappedValue.name)"))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.xs)
        .listRowInsets(.bottom, Spacing.s)
    }

}

// MARK: - Pieces

extension ExerciseTrackerView {

    /// One piece of the table, laid out as the whole table lays it out.
    @ViewBuilder
    func pieceView(_ piece: ExerciseTrackerPiece) -> some View {
        switch piece {
        case .header:
            if let card = delegate.card {
                cardHeader(card)
            }
        case .actions:
            memberActionsMenu
        case .progressionNote:
            progressionNoteRow
        case let .columnHeadings(label):
            columnHeaders(setLabel: label).setTableRow()
        case .loggedWarmups:
            loggedWarmupsGroup.setTableRow()
        case let .row(setId, badge, isNext, startsRound, endsRound):
            if let set = delegate.exercise.wrappedValue.sets.first(where: { $0.id == setId }) {
                Group {
                    // One VoiceOver container per row, named for its set and exercise, so the
                    // Containers rotor steps through the rounds: "B1, set 1, Bench Press", and a
                    // drop under it "B1, set 1 drop set 1, Bench Press".
                    let name = [ActiveWorkout.spokenBadge(badge), ActiveWorkout.subSetName(of: set, in: delegate.exercise.wrappedValue.sets)]
                        .compactMap { $0 }.joined(separator: " ")
                    // Within a round the rows run together; a separator divides the rounds.
                    row(for: set, badge: badge, isNext: isNext, separators: (startsRound ? .visible : .hidden, endsRound ? .visible : .hidden))
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel([name, delegate.exercise.wrappedValue.name].joined(separator: ", "))
                    restRow(below: set)
                }
                .setTableRow()
            }
        case .notes:
            notesRow
        }
    }
}

// MARK: - Previews

/// Last session's sets as today's plan, the first logged a minute ago.
@MainActor
private func previewExercise() -> WorkoutExerciseModel {
    var exercise = WorkoutExerciseModel.mock
    for index in exercise.sets.indices {
        exercise.sets[index].completedAt = index == 0 ? .now.addingTimeInterval(-60) : nil
    }
    return exercise
}

/// The live tracker's card (`ExerciseCard`): the title row with its menu, the progression note,
/// the rest running under the set just logged, and logging through the card.
#Preview("Live tracker card") {
    @Previewable @State var exercise = previewExercise()
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))

    RouterView { router in
        List {
            builder.exerciseTrackerView(router: router, delegate: ExerciseTrackerDelegate(
                exercise: $exercise,
                lastExercise: .mock,
                card: ExerciseCard(
                    progressionNote: "+2.5 kg today. You hit 10 reps on every working set last time.",
                    restTimer: exercise.sets.first.map {
                        InlineRestTimer(anchor: .below(setId: $0.id), startedAt: .now.addingTimeInterval(-60), endsAt: .now.addingTimeInterval(30))
                    },
                    onLogSet: { setId, _ in
                        guard let index = exercise.sets.firstIndex(where: { $0.id == setId }) else { return }
                        exercise.sets[index].completedAt = .now
                    }
                )
            ))
        }
    }
}

/// The finished workout's editor (`WorkoutSessionDetailView`): no card, the exercise as a row that
/// opens onto its sets, which stay editable.
#Preview("Finished workout editor") {
    @Previewable @State var exercise = WorkoutExerciseModel.mock
    @Previewable @State var isExpanded = true
    let builder = CoreBuilder(interactor: CoreInteractor(container: DevPreview.shared.container()))

    RouterView { router in
        List {
            Section {
                builder.exerciseTrackerView(router: router, delegate: ExerciseTrackerDelegate(
                    exercise: $exercise,
                    lastExercise: nil,
                    isExpanded: $isExpanded
                ))
            }
        }
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
            setTrackerRow: { delegate in
                self.setTrackerRowView(router: router, delegate: delegate)
            }
        )
    }
}
