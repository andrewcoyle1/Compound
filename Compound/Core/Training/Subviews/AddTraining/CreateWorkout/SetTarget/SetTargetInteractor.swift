import SwiftUI

@MainActor
protocol SetTargetInteractor: GlobalInteractor {
    /// Read for the set plan: whether it is on, and each kind's rest for the line under a set.
    var workoutSettings: WorkoutSettings { get }
    /// The library, to name the exercises a template exercise lists as substitutions.
    var allExercises: [ExerciseModel] { get }
}

extension CoreInteractor: SetTargetInteractor { }
