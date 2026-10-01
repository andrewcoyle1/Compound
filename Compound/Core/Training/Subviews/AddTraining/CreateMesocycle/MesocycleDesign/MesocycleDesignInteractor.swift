import SwiftUI

@MainActor
protocol MesocycleDesignInteractor: GlobalInteractor {
    var userId: String? { get }
    var favouriteGymProfile: GymProfileModel? { get }
    var activeMesocycle: Mesocycle? { get }
    func setActiveMesocycle(mesocycleId: String) async throws
    func saveMesocycle(mesocycle: Mesocycle) async throws
    func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws
    func deleteMesocycle(mesocycleId: String) async throws
}

extension CoreInteractor: MesocycleDesignInteractor { }
