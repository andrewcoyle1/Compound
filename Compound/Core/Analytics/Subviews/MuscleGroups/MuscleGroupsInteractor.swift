import SwiftUI

@MainActor
protocol MuscleGroupsInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var allExercises: [ExerciseModel] { get }
}

extension CoreInteractor: MuscleGroupsInteractor { }
