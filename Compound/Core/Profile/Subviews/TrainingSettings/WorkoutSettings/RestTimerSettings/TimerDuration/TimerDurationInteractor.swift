import SwiftUI

@MainActor
protocol TimerDurationInteractor: GlobalInteractor {
    var workoutSettings: WorkoutSettings { get }
    var allExercises: [ExerciseModel] { get }
    var allExerciseSettings: [ExerciseSettingsModel] { get }
    func saveWorkoutSettings(_ workoutSettings: WorkoutSettings) async throws
    func exerciseRestOverride(for exerciseId: String) -> Int?
    func setExerciseRestOverride(_ seconds: Int?, for exerciseId: String) async throws
}

extension CoreInteractor: TimerDurationInteractor { }
