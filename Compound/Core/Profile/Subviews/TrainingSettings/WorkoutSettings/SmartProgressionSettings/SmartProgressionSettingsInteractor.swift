import SwiftUI

@MainActor
protocol SmartProgressionSettingsInteractor: GlobalInteractor {
    var workoutSettings: WorkoutSettings { get }
    func saveWorkoutSettings(_ workoutSettings: WorkoutSettings) async throws
}

extension CoreInteractor: SmartProgressionSettingsInteractor { }
