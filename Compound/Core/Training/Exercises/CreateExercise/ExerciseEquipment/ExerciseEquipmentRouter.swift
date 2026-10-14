import SwiftUI

@MainActor
protocol ExerciseEquipmentRouter: GlobalRouter {
    func showEquipmentPickerView(delegate: EquipmentPickerDelegate)
    func showFinalExerciseDetailsView(delegate: FinalExerciseDetailsDelegate)

}

extension CoreRouter: ExerciseEquipmentRouter { }
