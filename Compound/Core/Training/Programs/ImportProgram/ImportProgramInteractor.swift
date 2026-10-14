//
//  ImportProgramInteractor.swift
//  Compound
//

@MainActor
protocol ImportProgramInteractor: GlobalInteractor {
    var userId: String? { get }
    var allExercises: [ExerciseModel] { get }
    func saveExerciseModel(exercise: ExerciseModel, image: PlatformImage?) async throws
    func saveMesocycle(mesocycle: Mesocycle) async throws
    func saveMacrocycle(_ macrocycle: Macrocycle) async throws
}

extension CoreInteractor: ImportProgramInteractor { }
