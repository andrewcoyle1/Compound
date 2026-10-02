import SwiftUI

@MainActor
protocol ExerciseAnalyticsInteractor: GlobalInteractor {
    var auth: UserAuthInfo? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var systemExercises: [ExerciseModel] { get }
    var userExercises: [ExerciseModel] { get }
    func getPreference(templateId: String) -> ExerciseUnitPreference
}

extension CoreInteractor: ExerciseAnalyticsInteractor { }
