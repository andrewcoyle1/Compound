import SwiftUI

@MainActor
protocol SetTargetRouter: GlobalRouter {
    func showSetPlanDetailView(delegate: SetPlanDetailDelegate)
    /// The exercise picker, choosing a template exercise's substitutions.
    func showExercisesPickerView(delegate: ExercisesPickerDelegate)
    func showMicrocycleVariationsView(delegate: MicrocycleVariationsDelegate)
}

extension CoreRouter: SetTargetRouter { }
