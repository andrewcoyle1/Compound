//
//  SharedItemInteractor.swift
//  DialedIn
//

@MainActor
protocol SharedItemInteractor: GlobalInteractor {
    var userId: String? { get }
    var allExercises: [ExerciseModel] { get }
    func saveExerciseModel(exercise: ExerciseModel, image: PlatformImage?) async throws
    func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws
    func saveTrainingProgram(trainingProgram: TrainingProgram) async throws
    func updateShareStatus(_ status: ShareModel.Status, id: String) async throws
}

extension CoreInteractor: SharedItemInteractor { }
