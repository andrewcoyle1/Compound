import SwiftUI

@MainActor
protocol PrevWORefSettingsInteractor: GlobalInteractor {
    var workoutSettings: WorkoutSettings { get }
    func saveWorkoutSettings(_ workoutSettings: WorkoutSettings) async throws
}

extension CoreInteractor: PrevWORefSettingsInteractor { }
