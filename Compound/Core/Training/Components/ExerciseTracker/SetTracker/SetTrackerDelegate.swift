//
//  SetTrackerDelegate.swift
//  Compound
//
//  What the set table is handed: the exercise, the live tracker's card, and which piece of the
//  table a superset's card wants.
//

import SwiftUI

struct SetTrackerDelegate {
    let exercise: Binding<WorkoutExerciseModel>
    let lastExercise: WorkoutExerciseModel?
    /// What smart progression suggests for this exercise, one entry per working set.
    var progressionSuggestion: ProgressionSuggestion?
    var allWorkoutExercises: [WorkoutExerciseModel] = []
    var onSetSupersetGroup: @MainActor (String, String?) -> Void = { _, _ in }
    var onDeleteExercise: @MainActor () -> Void = { }
    /// The live tracker makes a swap itself, keeping the logged sets on the old exercise. `nil`
    /// swaps in place, as a finished workout's editor does. See `SetTrackerPresenter.onSwapPressed`.
    var onSwap: (@MainActor (ExerciseModel) -> Void)?
    /// The live tracker's card: the exercise's actions in an overflow menu that `header` places,
    /// the rest timer among the rows, and logging through the tracker.
    var card: SetTrackerCard?
}

/// What the live tracker adds to the set table: the tracker's `ExerciseCard`, and what the
/// exercise card builds around it.
struct SetTrackerCard {
    /// The card's title row, handed the actions menu to place in it.
    var header: (AnyView) -> AnyView
    /// The exercise's notes, under the sets; the actions menu opens their sheet.
    var notes: AnyView?
    var onNotePressed: @MainActor () -> Void = { }
    /// Opens the plan's video link; `nil` when there is none to open.
    var onWatch: (@MainActor () -> Void)?
    var exerciseCard: ExerciseCard
}

/// A piece of one exercise's set table. See `SupersetBlockView`.
enum SetTrackerPiece: Equatable {
    /// The member's line in the superset's header: its label and name, without a menu.
    case header
    /// The exercise's actions as a submenu of the superset's menu, named for the member.
    case actions
    /// Smart progression's note, over the rows.
    case progressionNote
    /// The column headings, with `label` (the member's, "B2") in the Set column's place when each
    /// member has its own; `nil` reads "Set".
    case columnHeadings(label: String?)
    /// The logged warm-ups, folded into one line.
    case loggedWarmups
    /// A set's row with `badge` in its circle, and the rest under it when it follows that set.
    /// Only the row the log button logs next (`isNext`) is current. Separators are drawn only
    /// between rounds: above a row that `startsRound`, under one that `endsRound`.
    case row(setId: String, badge: String, isNext: Bool, startsRound: Bool, endsRound: Bool)
    /// The exercise's notes.
    case notes
}
