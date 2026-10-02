import SwiftUI

@MainActor
protocol MuscleBalanceInteractor: GlobalInteractor {
    var workoutSessions: [WorkoutSessionModel] { get }
    var allExercises: [ExerciseModel] { get }
}

extension CoreInteractor: MuscleBalanceInteractor { }
