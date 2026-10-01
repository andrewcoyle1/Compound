import SwiftUI

@MainActor
protocol RestTimerSettingsInteractor: GlobalInteractor {
    var workoutSettings: WorkoutSettings { get }
    func saveWorkoutSettings(_ workoutSettings: WorkoutSettings) async throws
}

extension CoreInteractor: RestTimerSettingsInteractor { }
