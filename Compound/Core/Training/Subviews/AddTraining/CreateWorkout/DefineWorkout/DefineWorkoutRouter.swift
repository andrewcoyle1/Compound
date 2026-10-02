import SwiftUI

@MainActor
protocol DefineWorkoutRouter: GlobalRouter {
    func showExercisesPickerView(delegate: ExercisesPickerDelegate)
    func showSetTargetView(delegate: SetTargetDelegate)
}

extension CoreRouter: DefineWorkoutRouter { }
