//
//  ActiveWorkout+PrimarySlot.swift
//  Compound
//
//  The button at the foot of the tracker: what it does at a given moment, and when a tap on it
//  counts. One slot cycles through log, skip rest, next, finish and resume, so a second tap or a
//  tap as the rest runs out must never land on an action the person did not see.
//

import Foundation

extension ActiveWorkout {

    /// What the bottom button does.
    enum SlotAction: Equatable {
        case log(exerciseId: String, setId: String)
        case skipRest
        case next(exerciseId: String)
        case finish
        case resume
    }

    /// How long a naturally expired rest keeps the button showing "Rest done" and disabled, so a
    /// tap meant for Skip Rest as the timer reaches 0:00 does not log the next set.
    static let restDoneGrace: TimeInterval = 1

    /// How long after the button's action changes a tap on it is ignored: the second tap of a
    /// double tap lands on whatever the first one turned the button into.
    static let slotTapLockout: TimeInterval = 0.4

    /// Paused, the button resumes; while a rest runs, it ends the rest; otherwise it does the
    /// workout's next step.
    static func slotAction(primary: ActiveWorkoutAction?, restEnd: Date?, isPaused: Bool, now: Date) -> SlotAction? {
        if isPaused { return .resume }
        if let restEnd, now < restEnd { return .skipRest }
        switch primary {
        case let .logSet(exerciseId, setId)?: return .log(exerciseId: exerciseId, setId: setId)
        case let .next(exerciseId)?: return .next(exerciseId: exerciseId)
        case .finish?: return .finish
        case nil: return nil
        }
    }

    /// True for the second after a rest ran out on its own. A rest skipped early never reaches
    /// its end, so it never has a grace.
    static func isInGrace(restEnd: Date, now: Date) -> Bool {
        now >= restEnd && now < restEnd.addingTimeInterval(restDoneGrace)
    }

    /// Whether a tap at `now` counts. Keyed on the action, not its label: typing into the current
    /// set changes the title on every keystroke but leaves the button doing the same thing.
    static func acceptsTap(lastActionChangeAt: Date?, now: Date) -> Bool {
        guard let lastActionChangeAt else { return true }
        return now.timeIntervalSince(lastActionChangeAt) >= slotTapLockout
    }
}
