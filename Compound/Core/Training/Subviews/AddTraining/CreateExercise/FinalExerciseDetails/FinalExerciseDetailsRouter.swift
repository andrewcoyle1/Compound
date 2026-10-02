import SwiftUI

@MainActor
protocol FinalExerciseDetailsRouter: GlobalRouter {
    func showExerciseSaveView(delegate: ExerciseSaveDelegate)
}

extension CoreRouter: FinalExerciseDetailsRouter { }
