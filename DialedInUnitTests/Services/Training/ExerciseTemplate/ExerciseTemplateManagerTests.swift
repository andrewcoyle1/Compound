//
//  ExerciseModelManagerTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 28/10/2025.
//

import Testing
import Foundation
@testable import DialedIn

/// The manager keeps two libraries: the seeded system exercises, read from local persistence, and
/// the user's own, synced from Firestore. Most of what this file used to cover — fetching by name,
/// top-by-clicks, bookmarking, favouriting, interaction counts — went with the services layer those
/// methods lived on; the manager now only reads the two collections and saves or deletes the user's.
@MainActor
struct ExerciseModelManagerTests {

    private func exercise(id: String, name: String, isSystem: Bool = false) -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "author-1",
            name: name,
            trackableMetrics: [.weight, .reps],
            type: .compoundUpper,
            laterality: .bilateral,
            muscleGroups: [.chest: .primary],
            isBodyweight: false,
            equipmentVariations: [],
            rangeOfMotion: 4,
            stability: 5,
            bodyWeightContribution: 0,
            alternateNames: [],
            isSystemExercise: isSystem
        )
    }

    // MARK: - The two libraries

    @Test("Test System Exercises Come From Local Persistence")
    func testSystemExercisesComeFromLocalPersistence() {
        let manager = TestManagers.exerciseModelManager(
            system: [exercise(id: "system-1", name: "System Exercise", isSystem: true)]
        )

        #expect(manager.systemExercises.count == 1)
        #expect(manager.systemExercises[0].id == "system-1")
    }

    @Test("Test System Exercises Are Empty When None Are Seeded")
    func testSystemExercisesAreEmptyWhenNoneAreSeeded() {
        #expect(TestManagers.exerciseModelManager().systemExercises.isEmpty)
    }

    @Test("Test User Exercises Are Empty Until Signed In")
    func testUserExercisesAreEmptyUntilSignedIn() {
        // The sync engine holds nothing until it listens, so the user's library needs a sign-in
        // even though the remote already has exercises for them.
        let manager = TestManagers.exerciseModelManager(user: ExerciseModel.userMocks)

        #expect(manager.userExercises.isEmpty)
    }

    @Test("Test Signing In Loads The User's Own Exercises")
    func testSigningInLoadsTheUsersOwnExercises() async {
        let manager = TestManagers.exerciseModelManager(user: ExerciseModel.userMocks)

        await manager.signIn(userId: "mock_user_123")

        #expect(manager.userExercises.count == ExerciseModel.userMocks.count)
    }

    @Test("Test All Exercises Joins Both Libraries")
    func testAllExercisesJoinsBothLibraries() async {
        let manager = TestManagers.exerciseModelManager(
            user: [exercise(id: "user-1", name: "Mine")],
            system: [exercise(id: "system-1", name: "Seeded", isSystem: true)]
        )
        await manager.signIn(userId: "author-1")

        #expect(manager.allExercises.count == 2)
        #expect(manager.allExercises.map(\.id).contains("system-1"))
        #expect(manager.allExercises.map(\.id).contains("user-1"))
    }

    /// Both libraries are sorted by name, so the picker reads alphabetically rather than in
    /// whatever order Firestore answered in.
    @Test("Test Each Library Is Sorted By Name")
    func testEachLibraryIsSortedByName() async {
        let manager = TestManagers.exerciseModelManager(
            user: [exercise(id: "u2", name: "Zercher Squat"), exercise(id: "u1", name: "Ab Wheel")],
            system: [
                exercise(id: "s2", name: "Pull Up", isSystem: true),
                exercise(id: "s1", name: "Bench Press", isSystem: true)
            ]
        )
        await manager.signIn(userId: "author-1")

        #expect(manager.systemExercises.map(\.name) == ["Bench Press", "Pull Up"])
        #expect(manager.userExercises.map(\.name) == ["Ab Wheel", "Zercher Squat"])
        // The seeded library comes first, so a user's "Ab Wheel" does not lead the whole list.
        #expect(manager.allExercises.map(\.name) == ["Bench Press", "Pull Up", "Ab Wheel", "Zercher Squat"])
    }

    // MARK: - Writing

    @Test("Test Saving An Exercise Adds It To The User's Library")
    func testSavingAnExerciseAddsItToTheUsersLibrary() async throws {
        let manager = TestManagers.exerciseModelManager()
        await manager.signIn(userId: "author-1")

        try await manager.saveExerciseModel(exercise: exercise(id: "new-1", name: "New Exercise"), image: nil)

        let added = await TestManagers.eventually { manager.userExercises.map(\.id).contains("new-1") }
        #expect(added)
    }

    @Test("Test Deleting An Exercise Removes It From The User's Library")
    func testDeletingAnExerciseRemovesItFromTheUsersLibrary() async throws {
        let manager = TestManagers.exerciseModelManager(user: [exercise(id: "user-1", name: "Mine")])
        await manager.signIn(userId: "author-1")
        #expect(manager.userExercises.count == 1)

        try await manager.deleteExerciseModel(exerciseId: "user-1")

        let removed = await TestManagers.eventually { manager.userExercises.isEmpty }
        #expect(removed)
    }
}
