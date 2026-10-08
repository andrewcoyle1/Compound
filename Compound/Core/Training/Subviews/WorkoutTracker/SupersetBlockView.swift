//
//  SupersetBlockView.swift
//  Compound
//
//  A superset as one card (T6): a header line per member, then one table holding every member's
//  sets in the order they are done (A1, B1, A2, B2…, `ActiveWorkout.blockRows`), and an Add Set
//  per member. The log button walks the same rounds, so the card stays put while the block has
//  sets left and only the highlighted row moves.
//
//  Each piece is one member's own set table drawing just that piece (`SetTrackerPiece`), so a
//  row keeps its exercise's binding, menus, last-time figures and correction row.
//

import SwiftUI

struct SupersetBlockView<Piece: View>: View {

    /// In workout order; the first is A.
    let members: [WorkoutExerciseModel]
    let rows: [SupersetBlockRow]
    /// The set the log button logs next, the one row drawn as current.
    let nextSetId: String?
    /// One row of headings over every member's fields, when they share their columns.
    let showsColumnHeadings: Bool
    /// A rest that followed a set outside the superset, drawn once above its rows. One that
    /// followed a member's set is drawn under that set by the member's piece.
    let restBefore: InlineRestTimer?
    let onUndoManager: @MainActor (UndoManager?) -> Void
    /// One member's piece of the table, with Last or Auto as the card holds it.
    @ViewBuilder let piece: (_ exerciseId: String, _ piece: SetTrackerPiece, _ showAutoRanges: Bool) -> Piece

    /// The same stored choice each member's presenter reads and writes, watched here so a switch
    /// in the headings reaches every member's rows.
    @AppStorage(SetTrackerPresenter.showAutoRangesKey) private var showAutoRanges = false
    @Environment(\.undoManager) private var undoManager

    /// The card's rows on screen. The undo manager is let go only when none is.
    @State private var visibleRows = 0

    var body: some View {
        Group {
            ForEach(members) { member in
                piece(member.id, .header, showAutoRanges)
            }
            if showsColumnHeadings, let first = members.first {
                piece(first.id, .columnHeadings, showAutoRanges)
            }
            if let restBefore {
                InlineRestTimerRow(timer: restBefore)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.vertical, 0)
                    .listRowInsets(.leading, 0)
            }
            ForEach(rows) { row in
                switch row.kind {
                case .loggedWarmups:
                    piece(row.exerciseId, .loggedWarmups, showAutoRanges)
                case let .set(id, badge):
                    piece(row.exerciseId, .row(setId: id, badge: badge, isNext: id == nextSetId), showAutoRanges)
                }
            }
            ForEach(members) { member in
                piece(member.id, .addSet, showAutoRanges)
            }
        }
        .onAppear {
            visibleRows += 1
            onUndoManager(undoManager)
        }
        .onDisappear {
            visibleRows -= 1
            if visibleRows == 0 { onUndoManager(nil) }
        }
    }
}
