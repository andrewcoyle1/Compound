import SwiftUI

@MainActor
protocol WorkoutSettingsInteractor: GlobalInteractor {
    var workoutSettings: WorkoutSettings { get }
    func saveWorkoutSettings(_ workoutSettings: WorkoutSettings) async throws 
}

extension CoreInteractor: WorkoutSettingsInteractor { }
