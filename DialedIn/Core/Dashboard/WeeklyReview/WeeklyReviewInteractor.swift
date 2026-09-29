import SwiftUI

@MainActor
protocol WeeklyReviewInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var bodyMeasurements: [BodyMeasurementEntry] { get }
    var userMeals: [MealLogModel] { get }
    var currentDietPlan: DietPlan? { get }
    var allExercises: [ExerciseModel] { get }
}

extension CoreInteractor: WeeklyReviewInteractor { }
