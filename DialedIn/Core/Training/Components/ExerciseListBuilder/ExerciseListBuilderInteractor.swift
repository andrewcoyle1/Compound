import SwiftUI

@MainActor
protocol ExerciseListBuilderInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var userExercises: [ExerciseModel] { get }
    var systemExercises: [ExerciseModel] { get }
    var allExercises: [ExerciseModel] { get }
    /// For the "Gym" filter, which keeps only exercises performable with a chosen gym's equipment.
    var gymProfiles: [GymProfileModel] { get }
}

extension CoreInteractor: ExerciseListBuilderInteractor { }
