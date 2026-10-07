//
//  AMRAPProgression.swift
//  Compound
//
//  How an AMRAP set with a target progresses under the set plan (Workout Settings › Set Plan):
//  the target goes up a rep once it has been beaten twice running, and once it has reached the
//  ceiling (`WorkoutSettings.amrapAddsWeightAtTarget`) the set adds the normal weight increment
//  instead and its target goes back to where the template starts it. Pure, like the engine.
//

import Foundation

struct AMRAPProgression: Equatable {
    /// The target at which beating it adds weight rather than a rep.
    let ceiling: Int

    /// The next session's AMRAP set.
    ///
    /// - Parameters:
    ///   - templateTarget: the template's `amrapTargetReps`, where the target starts and returns to.
    ///   - last: this set in the most recent session; its `targetReps` is the target now standing.
    ///   - previous: this set in the session before that, if there was one.
    ///   - heavier: the engine's normal weight increment.
    func next(
        templateTarget: Int,
        last: WorkoutSetModel,
        previous: WorkoutSetModel?,
        heavier: (Double) -> Double
    ) -> SuggestedSet {
        let target = last.targetReps ?? templateTarget
        let beatenTwice = [last, previous].allSatisfy { set in (set?.reps).map { $0 > target } ?? false }

        guard beatenTwice else {
            return SuggestedSet(weightKg: last.weightKg, reps: target, targetReps: target)
        }
        // Bodyweight work has no weight to add, so its target keeps climbing.
        if target >= ceiling, let weight = last.weightKg {
            return SuggestedSet(weightKg: heavier(weight), reps: templateTarget, targetReps: templateTarget)
        }
        return SuggestedSet(weightKg: last.weightKg, reps: target + 1, targetReps: target + 1)
    }
}
