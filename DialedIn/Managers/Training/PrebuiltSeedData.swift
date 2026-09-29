//
//  PrebuiltSeedData.swift
//  DialedIn
//
//  Created by Andrew Coyle on 16/09/2026.
//

import Foundation

/// The bundled system data that `ExerciseModelManager` and `WorkoutTemplateManager` seed on
/// login, decoded once so mock data can be built from exactly the same source.
///
/// Mock exercises and workouts used to be hand-written and carried no `imageURL`, so the Mock
/// scheme and every preview fell back to `Constants.randomImage` instead of the exercise
/// artwork the seeded app actually shows — and their ids matched nothing in the seeded library.
enum PrebuiltSeedData {

    /// The 32 system exercises from `PrebuiltExercises.json`, with their stable `system-*` ids
    /// and asset-catalogue image names.
    static let exercises: [ExerciseModel] = {
        decode("PrebuiltExercises", as: PrebuiltExercisesContainer.self)?.exercises ?? []
    }()

    /// The system workout templates from `PrebuiltWorkouts.json`, resolved against `exercises`.
    /// Built the same way `WorkoutTemplateManager` builds them, so a mock workout holds the same
    /// exercises in the same order as the seeded one.
    static let workoutTemplates: [WorkoutTemplateModel] = {
        let container = decode("PrebuiltWorkouts", as: PrebuiltWorkoutsContainer.self)
        return container?.workouts.compactMap { $0.toModel(exercises: exercises) } ?? []
    }()

    /// The program templates from `PrebuiltPrograms.json`, resolved against `workoutTemplates`
    /// the same way `TrainingProgramManager` seeds them.
    static let programs: [TrainingProgram] = {
        let container = decode("PrebuiltPrograms", as: PrebuiltProgramsContainer.self)
        return container?.programs.compactMap { $0.toModel(workouts: workoutTemplates) } ?? []
    }()

    /// Looks up an exercise by its seeded id, for hand-written mocks that need a specific one.
    static func exercise(id: String) -> ExerciseModel? {
        exercises.first { $0.id == id }
    }

    private static func decode<T: Decodable>(_ resource: String, as type: T.Type) -> T? {
        // `Bundle.main` covers the app and every preview hosted by it. The fallback scan is for
        // hosts whose main bundle is not the app, such as the test runner.
        let url = Bundle.main.url(forResource: resource, withExtension: "json")
            ?? Bundle.allBundles.compactMap { $0.url(forResource: resource, withExtension: "json") }.first
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
