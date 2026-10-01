import SwiftUI

@MainActor
protocol ExerciseSettingsRouter: GlobalRouter {
    func showExerciseModelDetailView(delegate: ExerciseModelDetailDelegate)
    func showWorkoutNotesView(delegate: WorkoutNotesDelegate)
    func showRestTimerSettingsView(delegate: RestTimerSettingsDelegate)
    func showRestModal(
        primaryButtonAction: @escaping () -> Void,
        secondaryButtonAction: @escaping () -> Void,
        minutesSelection: Binding<Int>,
        secondsSelection: Binding<Int>
    )
}

extension CoreRouter: ExerciseSettingsRouter { }
