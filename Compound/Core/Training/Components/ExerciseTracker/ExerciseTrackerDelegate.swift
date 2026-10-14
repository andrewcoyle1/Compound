//
//  ExerciseTrackerDelegate.swift
//  Compound
//
//  What one exercise's set table is handed. The live tracker adds an `ExerciseCard`; without one
//  the table is the collapsible row a finished workout's editor uses.
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
    /// Saves the exercise's mesocycle note; `nil` outside a mesocycle, where there is none to edit.
    var onUpdateMesocycleNote: (@MainActor (String) -> Void)?
    /// The live tracker makes a swap itself, keeping the logged sets on the old exercise. `nil`
    /// swaps in place (`ExerciseTrackerPresenter.onSwapPressed`).
    var onSwap: (@MainActor (ExerciseModel) -> Void)?
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
    /// Rests set by hand, by set id.
    var customRestSeconds: [String: Int] = [:]
    /// One piece of the table rather than all of it, for a superset's card to place among its
    /// partners' rows. `nil` draws the whole table.
    var piece: ExerciseTrackerPiece?
    /// The member's label on a superset's card, "B1", shown in its header in place of a menu.
    var memberLabel: String?
    /// The bodyweight the movement lifts, while the setting is on: the header's badge and the rows'
    /// "BW" labels.
    var bodyweight: BodyweightContribution?
}

/// A piece of one exercise's set table. See `SupersetBlockView`.
enum ExerciseTrackerPiece: Equatable {
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
