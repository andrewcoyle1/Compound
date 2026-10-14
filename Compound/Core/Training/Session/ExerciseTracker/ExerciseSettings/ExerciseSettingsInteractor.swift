import SwiftUI

@MainActor
protocol ExerciseSettingsInteractor: GlobalInteractor {
    func getPreference(templateId: String) -> ExerciseUnitPreference
    func setWeightUnit(_ unit: ExerciseWeightUnit, for templateId: String)
    func setDistanceUnit(_ unit: ExerciseDistanceUnit, for templateId: String)
    var workoutSettings: WorkoutSettings { get }
    func exerciseNote(for exerciseId: String) -> String?
    func setExerciseNote(_ note: String?, for exerciseId: String) async throws
    func exerciseRestOverride(for exerciseId: String) -> Int?
    func setExerciseRestOverride(_ seconds: Int?, for exerciseId: String) async throws
}

extension CoreInteractor: ExerciseSettingsInteractor { }
