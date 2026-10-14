//
//  ActiveWorkout+Propagation.swift
//  Compound
//
//  The propagate-changes rule: a weight or reps edit carried onto the sets still to come.
//

import Foundation

extension ActiveWorkout {

    /// `sets` with `edit`'s weight and reps carried onto the open siblings that still hold what the
    /// edited set held before the edit began.
    ///
    /// - Matched on `original`, the value before the first keystroke, never on something typed on
    ///   the way: sets of 100, 100 and an 80 kg back-off, with 82.5 typed into the first, leave the
    ///   back-off alone however the typing passed through 80.
    /// - Kept within a side: a heavier weight on the left arm must not move the right arm's sets,
    ///   because the limbs are not equally strong and that is why they are logged apart.
    /// - Only open sets change, and only from an open set: correcting a logged set fixes that
    ///   record alone.
    static func propagate(edit: WorkoutSetModel, original: WorkoutSetModel, in sets: [WorkoutSetModel]) -> [WorkoutSetModel] {
        guard edit.completedAt == nil else { return sets }
        let weightChanged = original.weightKg != edit.weightKg
        let repsChanged = original.reps != edit.reps
        guard weightChanged || repsChanged else { return sets }

        return sets.map { sibling in
            guard sibling.id != edit.id,
                  sibling.side == edit.side,
                  sibling.completedAt == nil,
                  sibling.weightKg == original.weightKg,
                  sibling.reps == original.reps else { return sibling }
            var sibling = sibling
            if weightChanged { sibling.weightKg = edit.weightKg }
            if repsChanged { sibling.reps = edit.reps }
            return sibling
        }
    }
}
