import SwiftUI

@MainActor
protocol ExerciseListBuilderRouter: GlobalRouter {
    func showCreateExerciseView()
}

extension CoreRouter: ExerciseListBuilderRouter { }
