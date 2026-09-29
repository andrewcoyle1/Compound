//
//  ExerciseModelManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 24/09/2025.
//

import SwiftUI

@Observable
@MainActor
class ExerciseModelManager {
    
    private let userExerciseSyncEngine: CollectionSyncEngine<ExerciseModel>
    private let systemExercisePersistence: any LocalCollectionPersistence<ExerciseModel>

    private let userDefaults = UserDefaults.standard
    private static let hasSeededKey = "hasSeededPrebuiltExercisesV2"
    private static let seedingVersionKey = "prebuiltExercisesSeedingVersionV2"
    private static let currentSeedingVersion = 14

    /// Check if exercises have already been seeded
    var hasSeeded: Bool {
        userDefaults.bool(forKey: Self.hasSeededKey)
    }
    
    /// Get the current seeding version
    var seedingVersion: Int {
        userDefaults.integer(forKey: Self.seedingVersionKey)
    }

    var systemExercises: [ExerciseModel] {
        ((try? systemExercisePersistence.getCollection(managerKey: Keys.systemExerciseManagerKey)) ?? [])
            .sorted(by: { $0.name < $1.name })
    }
    
    var userExercises: [ExerciseModel] {
        userExerciseSyncEngine.currentCollection
            .sorted(by: { $0.name < $1.name })

    }
    
    var allExercises: [ExerciseModel] {
        systemExercises + userExercises
    }
    
    init(
        userExerciseSyncEngine: CollectionSyncEngine<ExerciseModel>,
        systemExercisePersistence: any LocalCollectionPersistence<ExerciseModel>
    ) {
        self.userExerciseSyncEngine = userExerciseSyncEngine
        self.systemExercisePersistence = systemExercisePersistence
    }
    
    func signIn(userId: String) async {
        await userExerciseSyncEngine.startListening { query in
            query.where("author_id", isEqualTo: userId)
        }
    }
    
    func signOut() {
        userExerciseSyncEngine.stopListening()
    }
        
    func saveExerciseModel(exercise: ExerciseModel, image: PlatformImage?) async throws {
        var exercise = exercise
        if let image {
            let path = "exercises/\(exercise.id)"
            let url = try await FirebaseImageUploadService().uploadImage(image: image, path: path)
            exercise.updateImageURL(imageUrl: url.absoluteString)
        }
        try await userExerciseSyncEngine.saveDocument(exercise)
    }
    
    func deleteExerciseModel(exerciseId: String) async throws {
        try await userExerciseSyncEngine.deleteDocument(id: exerciseId)
    }
    
    // SYSTEM EXERCISE SEEDING
    
    /// Seed pre-built exercises if not already seeded
    func seedExercisesIfNeeded() throws {
        guard !hasSeeded || seedingVersion < Self.currentSeedingVersion else { return }
        // Always clear before inserting — prevents accumulation from past version bumps
        try deleteExistingSystemExercises()
        let exercises = try loadPrebuiltExercises()
        try seedExercises(exercises)
        userDefaults.set(true, forKey: Self.hasSeededKey)
        userDefaults.set(Self.currentSeedingVersion, forKey: Self.seedingVersionKey)
    }
    
    /// Force re-seed exercises (useful for development/testing)
    func resetAndReseed() throws {
        // Delete existing system exercises
        try deleteExistingSystemExercises()
        
        // Reset seeding flags
        userDefaults.removeObject(forKey: Self.hasSeededKey)
        userDefaults.removeObject(forKey: Self.seedingVersionKey)
        
        // Seed again
        try seedExercisesIfNeeded()
    }
    
    // MARK: - Private Methods
    
    /// Load pre-built exercises from JSON bundle
    private func loadPrebuiltExercises() throws -> [ExerciseModel] {
        guard let url = Bundle.main.url(forResource: "PrebuiltExercises", withExtension: "json") else {
            throw SeedingError.bundleNotFound
        }
        
        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(PrebuiltExercisesContainer.self, from: data)
        return container.exercises
    }
    
    private func seedExercises(_ exercises: [ExerciseModel]) throws {
        for exercise in exercises {
            try systemExercisePersistence.saveDocument(managerKey: Keys.systemExerciseManagerKey, exercise)
        }
    }
    
    /// Delete existing system exercises
    private func deleteExistingSystemExercises() throws {
        for exercise in systemExercises {
            try systemExercisePersistence.deleteDocument(managerKey: Keys.systemExerciseManagerKey, id: exercise.id)
        }
    }

}

extension CoreInteractor {
    
    // MARK: ExerciseModelManager
    
    var systemExercises: [ExerciseModel] {
        exerciseModelManager.systemExercises
    }
    
    var userExercises: [ExerciseModel] {
        exerciseModelManager.userExercises
    }
    
    var allExercises: [ExerciseModel] {
        exerciseModelManager.allExercises
    }
    
    func signIn(userId: String) async {
        await exerciseModelManager.signIn(userId: userId)
    }
    
    func signOut() {
        exerciseModelManager.signOut()
    }
        
    func saveExerciseModel(exercise: ExerciseModel, image: PlatformImage?) async throws {
        try await exerciseModelManager.saveExerciseModel(exercise: exercise, image: image)
    }
 
    func deleteExerciseModel(exerciseId: String) async throws {
        try await exerciseModelManager.deleteExerciseModel(exerciseId: exerciseId)
    }
    
    func seedExercisesIfNeeded() throws {
        try exerciseModelManager.seedExercisesIfNeeded()
    }

}

// MARK: - Supporting Types

/// Container for decoding JSON. Not private — `PrebuiltSeedData` decodes the same file to
/// build mock data from the seeded exercises.
struct PrebuiltExercisesContainer: Codable {
    let exercises: [ExerciseModel]
}

/// Errors that can occur during seeding
enum SeedingError: LocalizedError {
    case bundleNotFound
    case decodingFailed(Error)
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .bundleNotFound:
            return "PrebuiltExercises.json not found in app bundle"
        case .decodingFailed(let error):
            return "Failed to decode exercises: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save exercises: \(error.localizedDescription)"
        }
    }
}
