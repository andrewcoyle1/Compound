//
//  WorkoutTrackerPresenter+Superset.swift
//  Compound
//
//  Split out of WorkoutTrackerPresenter.swift, which is already at the 500-line type-body limit.
//  Moving focus between the members of a superset after a set is logged.
//

import SwiftUI

extension WorkoutTrackerPresenter {

    /// Moves focus to the next exercise in this superset once a set of it is logged.
    ///
    /// A superset is worked round-robin — a set of A, then a set of B, then back to A — so the
    /// card to have open after logging a set is the partner's, not the one just logged. Finishing
    /// an exercise outright is `advanceAfterExerciseCompletion`'s job and takes precedence; this
    /// is the step in between, which nothing moved before.
    ///
    /// The search runs forwards from the exercise just logged and wraps, so a group of three is
    /// cycled in its own order rather than always snapping back to the first member. A partner
    /// with every set already logged is skipped — there is nothing left to do on it.
    func advanceWithinSuperset(exerciseIndex: Int, in exercises: [WorkoutExerciseModel]) {
        guard interactor.workoutSettings.supersetAutoScroll,
              exercises.indices.contains(exerciseIndex),
              let groupId = exercises[exerciseIndex].supersetGroupId else { return }

        let wrappedOrder = (1..<exercises.count).map { (exerciseIndex + $0) % exercises.count }
        guard let nextIndex = wrappedOrder.first(where: {
            exercises[$0].supersetGroupId == groupId && !isComplete(exercises[$0])
        }) else { return }

        expandedExerciseId = exercises[nextIndex].id
        currentExerciseIndex = nextIndex
    }
}
