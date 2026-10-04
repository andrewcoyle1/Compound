import SwiftUI

@MainActor
protocol WorkoutSettingsRouter: GlobalRouter {
    func showRestTimerSettingsView(delegate: RestTimerSettingsDelegate)
    func showSmartProgressionSettingsView(delegate: SmartProgressionSettingsDelegate)
    func showExerciseAssessmentView(delegate: ExerciseAssessmentDelegate)
}

extension CoreRouter: WorkoutSettingsRouter { }
