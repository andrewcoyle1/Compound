//
//  SupersetBlockView.swift
//  Compound
//
//  A superset as one card: a header line per member, then one table holding every member's
//  sets in the order they are done (A1, B1, A2, B2…, `ActiveWorkout.blockRows`), and an Add Set
//  per member. The log button walks the same rounds, so the card stays put while the block has
//  sets left and only the next row to log changes.
//
//  Each piece is one member's own set table drawing just that piece (`SetTrackerPiece`), so a
//  row keeps its exercise's binding, menus, last-time figures and rest line.
//

import SwiftUI

/// What a superset's card draws, worked out by the presenter (`supersetCard(_:current:)`).
struct SupersetCard {
    /// In workout order; the first is A.
    let members: [WorkoutExerciseModel]
    let rows: [SupersetBlockRow]
    /// The set the log button logs next, which VoiceOver names "next to log".
    let nextSetId: String?
    /// One row of headings over every member's fields, when they share their columns.
    let showsColumnHeadings: Bool
    /// A rest that followed a set outside the superset, drawn once above its rows. One that
    /// followed a member's set is drawn under that set by the member's piece.
    let restBefore: InlineRestTimer?
}

struct SupersetBlockView<Piece: View>: View {

    let card: SupersetCard
    /// One member's piece of the table.
    @ViewBuilder let piece: (_ exerciseId: String, _ piece: SetTrackerPiece) -> Piece

    var body: some View {
        Section {
            ForEach(card.members) { member in
                piece(member.id, .progressionNote)
            }
            if card.showsColumnHeadings, let first = card.members.first {
                piece(first.id, .columnHeadings)
            }
            if let restBefore = card.restBefore {
                InlineRestTimerRow(timer: restBefore)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.vertical, 0)
                    .listRowInsets(.leading, 0)
            }
            ForEach(card.rows) { row in
                switch row.kind {
                case .loggedWarmups:
                    piece(row.exerciseId, .loggedWarmups)
                case let .set(id, badge):
                    piece(row.exerciseId, .row(setId: id, badge: badge, isNext: id == card.nextSetId))
                }
            }
            ForEach(card.members) { member in
                piece(member.id, .addSet)
            }
        } header: {
            // A title line per member, each with its own actions menu.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(card.members) { member in
                    piece(member.id, .header)
                }
            }
        }
        .listSectionMargins(.top, Spacing.s)
    }
}
