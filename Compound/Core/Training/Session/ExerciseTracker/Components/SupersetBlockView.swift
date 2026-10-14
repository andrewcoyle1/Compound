//
//  SupersetBlockView.swift
//  Compound
//
//  A superset as one card. The header names the superset ("Superset B", lettered as the strip
//  and the templates letter it) and its members (B1, B2), with one menu: the block's own
//  actions, then a submenu per member. Under it one table holds every member's sets in the order
//  they are done (B1·1, B2·1, B1·2…, `ActiveWorkout.blockRows`), a separator between rounds, and
//  one Add Round. The log button walks the same rounds, so the card stays put while the block
//  has sets left and only the next row to log changes.
//
//  Each piece is one member's own set table drawing just that piece (`ExerciseTrackerPiece`), so a
//  row keeps its exercise's binding, menus, last-time figures and rest line.
//

import SwiftUI

/// What a superset's card draws, worked out by the presenter (`supersetCard(_:current:)`).
struct SupersetCard {
    /// The superset's own letter (`ActiveWorkout.supersetLetters`).
    let letter: String
    /// In workout order; the first is `letter`1.
    let members: [WorkoutExerciseModel]
    let rows: [SupersetBlockRow]
    /// The set the log button logs next, which VoiceOver names "next to log".
    let nextSetId: String?
    /// One row of headings over every member's fields, when they share their columns; otherwise
    /// one row per member.
    let showsColumnHeadings: Bool
    /// A rest that followed a set outside the superset, or a warm-up, drawn once under the folded
    /// warm-ups. One that followed a member's working set is drawn under that set by its piece.
    let restBefore: InlineRestTimer?
    var onAddRound: @MainActor () -> Void = { }
    /// Moves the whole superset to the end; `nil` when there is nothing to put it behind.
    var onDoLater: (@MainActor () -> Void)?
    var onRemoveSuperset: @MainActor () -> Void = { }
}

struct SupersetBlockView<Piece: View>: View {

    let card: SupersetCard
    /// One member's piece of the table.
    @ViewBuilder let piece: (_ exerciseId: String, _ piece: ExerciseTrackerPiece) -> Piece

    /// The folded warm-ups the rest before goes under: the last, as on a single exercise's card.
    private var restAnchorRowId: String? {
        card.rows.last { $0.kind == .loggedWarmups }?.id
    }

    var body: some View {
        Section {
            ForEach(card.members) { member in
                piece(member.id, .progressionNote)
            }
            columnHeadings
            if restAnchorRowId == nil {
                restBeforeRow
            }
            ForEach(Array(card.rows.enumerated()), id: \.element.id) { index, row in
                switch row.kind {
                case .loggedWarmups:
                    piece(row.exerciseId, .loggedWarmups)
                case let .set(id, badge):
                    piece(row.exerciseId, .row(
                        setId: id,
                        badge: badge,
                        isNext: id == card.nextSetId,
                        startsRound: index == 0 || card.rows[index - 1].endsRound,
                        endsRound: row.endsRound
                    ))
                }
                if row.id == restAnchorRowId {
                    restBeforeRow
                }
            }
            addRoundButton
            ForEach(card.members) { member in
                piece(member.id, .notes)
            }
        } header: {
            header
        }
        .listSectionMargins(.top, Spacing.s)
    }

    // MARK: - Header

    /// "Superset B" with the one menu, then a line per member.
    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .center, spacing: Spacing.s) {
                Text("Superset \(card.letter)")
                    .font(.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                menu
            }
            ForEach(card.members) { member in
                piece(member.id, .header)
            }
        }
        .foregroundStyle(.primary)
        .textCase(nil)
        .padding(.vertical, Spacing.s)
    }

    /// The block's own actions once, then each member's as a submenu.
    private var menu: some View {
        Menu {
            if let onDoLater = card.onDoLater {
                Button {
                    onDoLater()
                } label: {
                    Label("Do Later", systemImage: Symbol.doLater)
                }
            }
            Button {
                card.onRemoveSuperset()
            } label: {
                Label(
                    card.members.count > 2 ? String(localized: "Remove Circuit") : String(localized: "Remove Superset"),
                    systemImage: Symbol.superset
                )
            }
            Divider()
            ForEach(card.members) { member in
                piece(member.id, .actions)
            }
        } label: {
            Image(systemName: Symbol.more)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Superset options")
    }

    // MARK: - Table

    /// The headings once when the members share their columns, else one row per member, named.
    @ViewBuilder
    private var columnHeadings: some View {
        if card.showsColumnHeadings, let first = card.members.first {
            piece(first.id, .columnHeadings(label: nil))
        } else {
            ForEach(Array(card.members.enumerated()), id: \.element.id) { index, member in
                piece(member.id, .columnHeadings(label: ActiveWorkout.memberLabel(letter: card.letter, index: index)))
            }
        }
    }

    @ViewBuilder
    private var restBeforeRow: some View {
        if let restBefore = card.restBefore {
            InlineRestTimerRow(timer: restBefore)
                .setTableRow()
        }
    }

    /// A set more for every member: the next round.
    private var addRoundButton: some View {
        Button {
            card.onAddRound()
        } label: {
            Label("Add Round", systemImage: Symbol.add)
                .font(.label.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: ControlSize.row, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .listRowSeparator(.hidden)
        .listRowInsets(.bottom, Spacing.s)
    }
}

// MARK: - Previews

/// The workout's second superset ("B"), of two mock lifts, wired as
/// `WorkoutTrackerView.supersetCard` wires it: the card comes from the same rules as the
/// presenter's `supersetCard`, and each piece is that member's real set table drawing only that
/// piece. Sets are editable and Add Round adds a round; logging goes nowhere.
private struct SupersetBlockPreview: View {

    /// Rounds logged in both members, B1·1 B2·1 first.
    var loggedRounds: Int
    /// The rest drawn under B2's last logged set, as after a round.
    var restsAfterRound = false
    /// A rest after the exercise before, drawn under the folded warm-ups (`SupersetCard.restBefore`).
    var restBefore: InlineRestTimer?

    @State private var members: [WorkoutExerciseModel] = []
    private let last = Array(WorkoutExerciseModel.mocks.filter { $0.trackingMode == .weightReps }.prefix(2))

    var body: some View {
        let interactor = CoreInteractor(container: DevPreview.shared.container())
        let builder = CoreBuilder(interactor: interactor)
        RouterView { router in
            List {
                if !members.isEmpty {
                    SupersetBlockView(card: SupersetCard(
                        letter: "B",
                        members: members,
                        rows: ActiveWorkout.blockRows(members, letter: "B"),
                        nextSetId: ActiveWorkout.nextSetId(inBlock: members, current: members[0].id),
                        showsColumnHeadings: ActiveWorkout.blockSharesColumns(members) {
                            $0.units(interactor.getPreference(templateId: $0.templateId))
                        },
                        restBefore: restBefore,
                        onAddRound: { members = members.map { $0.addingSet(authorId: "mock_user_123") } }
                    )) { exerciseId, piece in
                        let index = members.firstIndex { $0.id == exerciseId } ?? 0
                        builder.exerciseCardView(
                            router: router,
                            delegate: ExerciseTrackerDelegate(
                                exercise: $members[index],
                                lastExercise: last[index],
                                allWorkoutExercises: members
                            ),
                            card: ExerciseCard(
                                restTimer: restTimer(for: members[index]),
                                piece: piece,
                                memberLabel: ActiveWorkout.memberLabel(letter: "B", index: index)
                            )
                        )
                    }
                }
            }
        }
        .onAppear { members = makeMembers() }
    }

    /// Last session's sets as today's plan, logged up to round `loggedRounds`, and B1 with a logged
    /// warm-up, which folds into one line.
    private func makeMembers() -> [WorkoutExerciseModel] {
        last.enumerated().map { member, exercise in
            var exercise = exercise
            exercise.supersetGroupId = "preview-superset"
            for index in exercise.sets.indices {
                let logged = index < loggedRounds
                exercise.sets[index].completedAt = logged ? .now.addingTimeInterval(Double(index * 2 + member - 10) * 60) : nil
            }
            if member == 0 {
                let first = exercise.sets[0]
                exercise.sets.insert(WorkoutSetModel(
                    id: "\(exercise.id)-warmup", authorId: first.authorId, index: 0,
                    reps: 10, weightKg: (first.weightKg ?? 0) / 2, isWarmup: true,
                    completedAt: .now.addingTimeInterval(-12 * 60), dateCreated: .now
                ), at: 0)
            }
            return exercise
        }
    }

    /// Under B2's last logged set, 40 s into a 90 s rest. B1 is handed none, as the presenter
    /// hands a member the rest only when it follows one of that member's sets.
    private func restTimer(for member: WorkoutExerciseModel) -> InlineRestTimer? {
        guard restsAfterRound, member.id == members.last?.id,
              let set = member.sets.last(where: { $0.completedAt != nil }) else { return nil }
        return InlineRestTimer(anchor: .below(setId: set.id), startedAt: .now.addingTimeInterval(-40), endsAt: .now.addingTimeInterval(50))
    }
}

#Preview("Mid-superset, resting") {
    SupersetBlockPreview(loggedRounds: 1, restsAfterRound: true)
}

#Preview("Starting, rest from the exercise before") {
    SupersetBlockPreview(
        loggedRounds: 0,
        restBefore: InlineRestTimer(anchor: .top, startedAt: .now.addingTimeInterval(-20), endsAt: .now.addingTimeInterval(70))
    )
}
