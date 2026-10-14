//
//  ExerciseCardView.swift
//  Compound
//
//  The live tracker's card for one exercise: its title row and menu, the progression note, the
//  set table with the rest running under the set just logged, Add Set and the notes. On a
//  superset's card it draws one piece at a time (`ExerciseTrackerPiece`). A finished workout's
//  editor draws the same table as `ExerciseEditorView`.
//

import SwiftUI

struct ExerciseCardView<SetTrackerRow: View>: View {

    @Environment(\.openURL) var openURL
    @AppStorage(ExerciseTrackerPresenter.showAutoRangesKey) private var showAutoRanges = false

    @State var presenter: ExerciseTrackerPresenter
    let delegate: ExerciseTrackerDelegate
    let card: ExerciseCard

    @ViewBuilder var setTrackerRow: (SetTrackerRowDelegate) -> SetTrackerRow

    var body: some View {
        Group {
            if let piece = card.piece {
                pieceView(piece)
            } else {
                Section {
                    tableBody
                } header: {
                    header
                }
                .listSectionMargins(.top, Spacing.s)
            }
        }
        .environment(\.showsBodyweightLoad, card.bodyweight != nil)
    }
    
    var exercise: WorkoutExerciseModel { delegate.exercise.wrappedValue }

    @ViewBuilder
    private var tableBody: some View {
        // The table runs to the card's edge.
        progressionNoteRow
        Group {
            ExerciseColumnHeadings(presenter: presenter, exercise: delegate.exercise)
            loggedWarmups
            // Under the folded warm-ups, so a rest after the last warm-up follows it.
            if let timer = card.restTimer, timer.anchor == .top {
                InlineRestTimerRow(timer: timer)
            }
            ForEach(exercise.unfoldedSets) { set in
                row(for: set)
                restRow(below: set)
            }
            AddSetButton {
                presenter.addSet(exercise: delegate.exercise)
            }
        }
        .setTableRow()
        .listSectionMargins(.top, 0)
        notesRow
    }

    /// Why smart progression changed today's numbers, above the sets until it is tapped.
    @ViewBuilder
    private var progressionNoteRow: some View {
        if let note = card.progressionNote {
            ProgressionNote(text: note, onAcknowledge: card.onProgressionNoteAcknowledged)
                .listRowSeparator(.hidden)
        }
    }

    /// The notes under the add-set button, with the list's own insets like the title row.
    @ViewBuilder
    private var notesRow: some View {
        if !shownNotes.isEmpty {
            noteCards
                .listRowSeparator(.hidden)
        }
    }
    
    /// One per note written: the mesocycle note (the plan's notes, read-only outside a mesocycle),
    /// the exercise note and this workout's.
    var shownNotes: [CardNote] {
        let canEditPlan = delegate.onUpdateMesocycleNote != nil
        return [
            presenter.planNotes(for: exercise).map {
                CardNote(id: "plan", title: canEditPlan ? "Mesocycle Note" : "Plan Note", symbol: Symbol.pinnedNote, text: $0, tab: canEditPlan ? .mesocycle : nil)
            },
            presenter.note(for: exercise).map {
                CardNote(id: "exercise", title: "Exercise Note", symbol: Symbol.pinnedNote, text: $0, tab: .exercise)
            },
            exercise.notes.map {
                CardNote(id: "session", title: "Session Note", symbol: Symbol.note, text: $0, tab: .session)
            }
        ].compactMap { $0 }
    }

    /// The notes as cards, each opening the sheet on its own tab.
    var noteCards: some View {
        VStack(spacing: Spacing.s) {
            ForEach(shownNotes) { note in
                NoteCard(note: note, onEdit: note.tab.map { tab in { presenter.openNotes(tab, for: delegate) } })
                    .accessibilityIdentifier(note.id == "plan" ? "ExerciseTracker.planNotes" : "")
            }
        }
    }

    /// The card's title row.
    var header: some View {
        ExerciseCardHeader(name: exercise.name, memberLabel: card.memberLabel, bodyweight: card.bodyweight) {
            MoreMenu {
                menuItems(isMember: false)
            }
            .accessibilityLabel("Exercise options")
        }
    }

    /// A superset member's actions, as a submenu of the superset's menu (`SupersetBlockView`),
    /// which holds Do Later and Remove Superset for the whole block.
    var memberActionsMenu: some View {
        Menu {
            menuItems(isMember: true)
        } label: {
            Text([card.memberLabel, exercise.name].compactMap { $0 }.joined(separator: " "))
        }
    }

    /// Watch, when the plan links a video the browser can open.
    private var watchAction: (@MainActor () -> Void)? {
        guard let url = presenter.watchURL(for: exercise) else { return nil }
        return { presenter.onWatchPressed(url, open: openURL) }
    }

    @ViewBuilder
    private func menuItems(isMember: Bool) -> some View {
        Button {
            presenter.openNotes(for: delegate)
        } label: {
            Label("Notes", systemImage: Symbol.note)
        }
        if !isMember, let onDoLater = card.onDoLater {
            Button {
                onDoLater()
            } label: {
                Label("Do Later", systemImage: Symbol.doLater)
            }
        }
        if let onWatch = watchAction {
            Button {
                onWatch()
            } label: {
                Label("Watch", systemImage: Symbol.video)
            }
        }
        Divider()
        if isMember {
            Button {
                presenter.addSet(exercise: delegate.exercise)
            } label: {
                Label("Add Set", systemImage: Symbol.add)
            }
        }
        ExerciseActionButtons(presenter: presenter, delegate: delegate, includesSuperset: !isMember)
        Divider()
        Button {
            presenter.onExerciseSettingsPressed(exercise: delegate.exercise.wrappedValue)
        } label: {
            Label("Exercise Settings", systemImage: Symbol.settings)
        }

        Button(role: .destructive) {
            presenter.deleteExercise(delegate.exercise, onDelete: delegate.onDeleteExercise)
        } label: {
            Label("Delete", systemImage: Symbol.delete)
        }
    }

    private var loggedWarmups: some View {
        LoggedWarmupsGroup(sets: exercise.loggedWarmups) { set in
            row(for: set)
        }
    }

    /// On a superset's card only the set the log button logs next (`isNext`) is current.
    private func row(
        for set: WorkoutSetModel,
        badge: String? = nil,
        isNext: Bool? = nil,
        separators: (top: Visibility, bottom: Visibility) = (.visible, .visible)
    ) -> some View {
        var row = delegate.rowDelegate(for: set, showAutoRanges: showAutoRanges)
        row.rowState = if let isNext {
            ActiveWorkout.blockRowState(of: set, in: exercise, isNext: isNext)
        } else {
            ActiveWorkout.rowState(of: set, in: exercise)
        }
        row.onLogSet = card.onLogSet
        row.onCustomRestChanged = card.onCustomRestChanged
        row.customRestSeconds = card.customRestSeconds[set.id]
        row.badgeLabel = badge
        return setTrackerRow(row)
            .listRowSeparator(separators.top, edges: .top)
            .listRowSeparator(separators.bottom, edges: .bottom)
    }

    /// Under the set just logged: the rest it started. Correcting the set is the bar over the
    /// log button (`WorkoutTrackerPresenter.restCorrection`).
    @ViewBuilder
    private func restRow(below set: WorkoutSetModel) -> some View {
        if let timer = card.restTimer, timer.anchor == .below(setId: set.id) {
            InlineRestTimerRow(timer: timer)
        }
    }

    // MARK: - Pieces

    /// One piece of the table, laid out as the whole table lays it out.
    @ViewBuilder
    private func pieceView(_ piece: ExerciseTrackerPiece) -> some View {
        switch piece {
        case .header:
            header
        case .actions:
            memberActionsMenu
        case .progressionNote:
            progressionNoteRow
        case let .columnHeadings(label):
            ExerciseColumnHeadings(presenter: presenter, exercise: delegate.exercise, setLabel: label).setTableRow()
        case .loggedWarmups:
            loggedWarmups.setTableRow()
        case let .row(setId, badge, isNext, startsRound, endsRound):
            if let set = exercise.sets.first(where: { $0.id == setId }) {
                Group {
                    // One VoiceOver container per row, named for its set and exercise, so the
                    // Containers rotor steps through the rounds: "B1, set 1, Bench Press", and a
                    // drop under it "B1, set 1 drop set 1, Bench Press".
                    let name = [ActiveWorkout.spokenBadge(badge), ActiveWorkout.subSetName(of: set, in: exercise.sets)]
                        .compactMap { $0 }.joined(separator: " ")
                    // Within a round the rows run together; a separator divides the rounds.
                    row(for: set, badge: badge, isNext: isNext, separators: (startsRound ? .visible : .hidden, endsRound ? .visible : .hidden))
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel([name, exercise.name].joined(separator: ", "))
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
            builder.exerciseCardView(
                router: router,
                delegate: ExerciseTrackerDelegate(exercise: $exercise, lastExercise: .mock),
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
            )
        }
    }
}

extension CoreBuilder {
    func exerciseCardView(
        router: AnyRouter,
        delegate: ExerciseTrackerDelegate,
        card: ExerciseCard
    ) -> some View {
        ExerciseCardView(
            presenter: ExerciseTrackerPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            card: card,
            setTrackerRow: { delegate in
                self.setTrackerRowView(router: router, delegate: delegate)
            }
        )
    }
}
