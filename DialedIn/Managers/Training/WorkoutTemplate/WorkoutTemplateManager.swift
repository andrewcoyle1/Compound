//
//  WorkoutTemplateManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/09/2025.
//

import SwiftUI

@Observable
@MainActor
class WorkoutTemplateManager {

    private let userWorkoutTemplateSyncEngine: CollectionSyncEngine<WorkoutTemplateModel>
    private let systemWorkoutTemplatePersistence: any LocalCollectionPersistence<WorkoutTemplateModel>

    /// Injectable only so a test can point the seeding flags at storage of its own; the app
    /// always uses `.standard`, which is where the developer menu reads and clears the same keys.
    private let userDefaults: UserDefaults
    private static let hasSeededKey = "hasSeededPrebuiltWorkouts"
    private static let seedingVersionKey = "prebuiltWorkoutsSeedingVersion"
    private static let currentSeedingVersion = 4

    var hasSeeded: Bool {
        userDefaults.bool(forKey: Self.hasSeededKey)
    }

    var seedingVersion: Int {
        userDefaults.integer(forKey: Self.seedingVersionKey)
    }

    var systemWorkoutTemplates: [WorkoutTemplateModel] {
        (try? systemWorkoutTemplatePersistence.getCollection(managerKey: Keys.systemWorkoutTemplateManagerKey)) ?? []
    }

    var userWorkoutTemplates: [WorkoutTemplateModel] {
        userWorkoutTemplateSyncEngine.currentCollection
    }

    var allWorkoutTemplates: [WorkoutTemplateModel] {
        systemWorkoutTemplates + userWorkoutTemplates
    }

    init(
        userWorkoutTemplateSyncEngine: CollectionSyncEngine<WorkoutTemplateModel>,
        systemWorkoutTemplatePersistence: any LocalCollectionPersistence<WorkoutTemplateModel>,
        userDefaults: UserDefaults = .standard
    ) {
        self.userWorkoutTemplateSyncEngine = userWorkoutTemplateSyncEngine
        self.systemWorkoutTemplatePersistence = systemWorkoutTemplatePersistence
        self.userDefaults = userDefaults
    }

    func signIn() async {
        await userWorkoutTemplateSyncEngine.startListening()
    }

    func signOut() {
        userWorkoutTemplateSyncEngine.stopListening()
    }

    // MARK: - System Workout Template Seeding

    func seedWorkoutTemplatesIfNeeded(exercises: [ExerciseModel]) throws {
        guard !hasSeeded || seedingVersion < Self.currentSeedingVersion else { return }

        // Prebuilt workouts are resolved against the exercise library, and loadPrebuiltWorkouts
        // compactMaps away any workout whose exercises are missing. With no exercises every
        // workout drops, so carrying on here would delete the templates the user already has,
        // seed nothing in their place, and still mark the library as seeded — leaving them
        // permanently without prebuilt workouts and no retry. Exercises seed before workouts,
        // but a caller that gets that ordering wrong should lose nothing.
        guard !exercises.isEmpty else { return }

        let workouts = try loadPrebuiltWorkouts(exercises: exercises)
        guard !workouts.isEmpty else { return }

        // Always clear before inserting — prevents accumulation from past version bumps
        try deleteExistingSystemWorkoutTemplates()
        try seedWorkouts(workouts)
        userDefaults.set(true, forKey: Self.hasSeededKey)
        userDefaults.set(Self.currentSeedingVersion, forKey: Self.seedingVersionKey)
    }

    func resetAndReseedWorkoutTemplates(exercises: [ExerciseModel]) throws {
        userDefaults.removeObject(forKey: Self.hasSeededKey)
        userDefaults.removeObject(forKey: Self.seedingVersionKey)
        try seedWorkoutTemplatesIfNeeded(exercises: exercises)
    }

    private func loadPrebuiltWorkouts(exercises: [ExerciseModel]) throws -> [WorkoutTemplateModel] {
        guard let url = Bundle.main.url(forResource: "PrebuiltWorkouts", withExtension: "json") else {
            throw SeedingError.bundleNotFound
        }
        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(PrebuiltWorkoutsContainer.self, from: data)
        return container.workouts.compactMap { $0.toModel(exercises: exercises) }
    }

    private func seedWorkouts(_ workouts: [WorkoutTemplateModel]) throws {
        for workout in workouts {
            try systemWorkoutTemplatePersistence.saveDocument(managerKey: Keys.systemWorkoutTemplateManagerKey, workout)
        }
    }

    private func deleteExistingSystemWorkoutTemplates() throws {
        for template in systemWorkoutTemplates {
            try systemWorkoutTemplatePersistence.deleteDocument(managerKey: Keys.systemWorkoutTemplateManagerKey, id: template.id)
        }
    }

    // MARK: - User Workout Templates

    func getWorkoutTemplate(id: String) -> WorkoutTemplateModel? {
        userWorkoutTemplateSyncEngine.getDocument(id: id)
    }

    func getWorkoutTemplate(id: String) async throws -> WorkoutTemplateModel {
        try await userWorkoutTemplateSyncEngine.getDocumentAsync(id: id)
    }

    func saveWorkoutTemplate(_ workoutTemplate: WorkoutTemplateModel, _ image: PlatformImage?) async throws {
        var workoutTemplate = workoutTemplate
        if let image {
            let path = "users/\(workoutTemplate.authorId)/workout_templates/\(workoutTemplate.id)"
            let url = try await FirebaseImageUploadService().uploadImage(image: image, path: path)
            workoutTemplate.updateImageURL(imageUrl: url.absoluteString)
        }
        try await userWorkoutTemplateSyncEngine.saveDocument(workoutTemplate)
    }

    func deleteWorkoutTemplate(id: String) async throws {
        try await userWorkoutTemplateSyncEngine.deleteDocument(id: id)
    }

}

// MARK: - Supporting Types

// Not private — `PrebuiltSeedData` decodes the same file to build mock data from the seeded
// workout templates.
struct PrebuiltWorkoutsContainer: Codable {
    let workouts: [PrebuiltWorkoutDTO]
}

struct PrebuiltWorkoutDTO: Codable {
    let workoutId: String
    let name: String
    let description: String?
    let isSystemWorkout: Bool
    let exerciseIds: [String]

    func toModel(exercises: [ExerciseModel]) -> WorkoutTemplateModel? {
        let workoutExercises: [WorkoutTemplateExercise] = exerciseIds.compactMap { exerciseId in
            guard let exercise = exercises.first(where: { $0.id == exerciseId }) else {
                return nil
            }
            return WorkoutTemplateExercise(exercise: exercise, setRestTimers: false)
        }
        guard !workoutExercises.isEmpty else {
            return nil
        }
        return WorkoutTemplateModel(
            id: workoutId,
            authorId: "official",
            name: name,
            description: description,
            imageURL: nil,
            dateCreated: Date(),
            dateModified: Date(),
            exercises: workoutExercises
        )
    }
}

extension CoreInteractor {
    // MARK: WorkoutTemplateManager

    var userWorkoutTemplates: [WorkoutTemplateModel] {
        workoutTemplateManager.userWorkoutTemplates
    }

    var systemWorkoutTemplates: [WorkoutTemplateModel] {
        workoutTemplateManager.systemWorkoutTemplates
    }

    var allWorkoutTemplates: [WorkoutTemplateModel] {
        workoutTemplateManager.allWorkoutTemplates
    }

    func getWorkoutTemplate(id: String) -> WorkoutTemplateModel? {
        workoutTemplateManager.getWorkoutTemplate(id: id)
    }

    func getWorkoutTemplate(id: String) async throws -> WorkoutTemplateModel {
        try await workoutTemplateManager.getWorkoutTemplate(id: id)
    }

    func saveWorkoutTemplate(workoutTemplate: WorkoutTemplateModel, image: PlatformImage?) async throws {
        try await workoutTemplateManager.saveWorkoutTemplate(workoutTemplate, image)
    }

    func deleteWorkoutTemplate(id: String) async throws {
        try await workoutTemplateManager.deleteWorkoutTemplate(id: id)
    }

    func seedWorkoutTemplatesIfNeeded() throws {
        try workoutTemplateManager.seedWorkoutTemplatesIfNeeded(exercises: exerciseModelManager.allExercises)
    }
}
