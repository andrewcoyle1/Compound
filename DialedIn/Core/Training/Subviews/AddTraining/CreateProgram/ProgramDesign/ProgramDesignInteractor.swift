import SwiftUI

@MainActor
protocol ProgramDesignInteractor: GlobalInteractor {
    var userId: String? { get }
    var favouriteGymProfile: GymProfileModel? { get }
    var activeTrainingProgram: TrainingProgram? { get }
    func setActiveTrainingProgram(programId: String) async throws
    func saveTrainingProgram(trainingProgram: TrainingProgram) async throws
    func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws
    func deleteTrainingProgram(programId: String) async throws
}

extension CoreInteractor: ProgramDesignInteractor { }
