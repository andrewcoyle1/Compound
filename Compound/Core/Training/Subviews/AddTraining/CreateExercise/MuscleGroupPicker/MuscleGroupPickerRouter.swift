import SwiftUI

@MainActor
protocol MuscleGroupPickerRouter {
    func showExerciseEquipmentView(delegate: ExerciseEquipmentDelegate)
}

extension CoreRouter: MuscleGroupPickerRouter { }
