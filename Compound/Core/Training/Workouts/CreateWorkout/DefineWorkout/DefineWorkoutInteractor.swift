import SwiftUI

@MainActor
protocol DefineWorkoutInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws 
}

extension CoreInteractor: DefineWorkoutInteractor { }
