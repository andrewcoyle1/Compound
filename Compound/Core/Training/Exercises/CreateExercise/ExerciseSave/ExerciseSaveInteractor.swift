import SwiftUI

@MainActor
protocol ExerciseSaveInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var allEquipmentTypes: [AnyEquipment] { get }
    func saveExerciseModel(exercise: ExerciseModel, image: PlatformImage?) async throws
}

extension CoreInteractor: ExerciseSaveInteractor { }
