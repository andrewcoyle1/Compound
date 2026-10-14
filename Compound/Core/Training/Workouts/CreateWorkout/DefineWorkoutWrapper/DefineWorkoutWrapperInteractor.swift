import SwiftUI

@MainActor
protocol DefineWorkoutWrapperInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws
}

extension CoreInteractor: DefineWorkoutWrapperInteractor { }
