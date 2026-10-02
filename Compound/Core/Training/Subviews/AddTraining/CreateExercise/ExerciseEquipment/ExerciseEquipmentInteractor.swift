import SwiftUI

@MainActor
protocol ExerciseEquipmentInteractor: GlobalInteractor {
    var allEquipmentTypes: [AnyEquipment] { get }
}

extension CoreInteractor: ExerciseEquipmentInteractor {
    var allEquipmentTypes: [AnyEquipment] {
        GymProfileModel.allEquipmentCatalog
    }
}
