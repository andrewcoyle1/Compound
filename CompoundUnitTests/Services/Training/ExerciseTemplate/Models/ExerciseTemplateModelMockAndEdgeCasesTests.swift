//
//  ExerciseTemplateModelMockAndEdgeCasesTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 28/10/2025.
//

import Testing
import Foundation
@testable import Compound

/// The exercises the app ships with, and the hand-written ones behind `userMocks`.
///
/// `ExerciseModel.mocks` is no longer a hand-written array: it is `PrebuiltExercises.json`, the
/// same file the app seeds a new account from. That makes these tests worth more than they were —
/// a malformed or renamed field in that JSON leaves `PrebuiltSeedData.exercises` empty and a new
/// user with no exercise library at all, which nothing else would catch.
///
/// The `eventParameters` tests that lived here went with `ExerciseModelModel`, which had one; so
/// did a run of edge cases asserting that a `String` property holds long, unicode or empty strings.
@MainActor
struct ExerciseModelSeedDataTests {

    // MARK: - The seeded library

    @Test("Test The Seeded Exercise Library Decodes")
    func testTheSeededExerciseLibraryDecodes() {
        #expect(!PrebuiltSeedData.exercises.isEmpty)
        #expect(ExerciseModel.mocks.count == PrebuiltSeedData.exercises.count)
    }

    @Test("Test Every Seeded Exercise Is Usable")
    func testEverySeededExerciseIsUsable() {
        for exercise in ExerciseModel.mocks {
            #expect(!exercise.id.isEmpty)
            #expect(!exercise.name.isEmpty)
            #expect(!exercise.trackableMetrics.isEmpty, "\(exercise.name) records nothing")
            #expect(!exercise.muscleGroups.isEmpty, "\(exercise.name) works no muscles")
        }
    }

    /// Seeded ids are stable and referenced by `PrebuiltWorkouts.json`, so a duplicate or a
    /// renamed one breaks the workouts that point at it.
    @Test("Test Seeded Exercise Ids Are Unique And Stable")
    func testSeededExerciseIdsAreUniqueAndStable() {
        let ids = ExerciseModel.mocks.map(\.id)
        let allSeeded = ids.allSatisfy { $0.hasPrefix("system-") }

        #expect(Set(ids).count == ids.count)
        #expect(allSeeded)
    }

    @Test("Test Seeded Exercises Are Marked As System Exercises")
    func testSeededExercisesAreMarkedAsSystemExercises() {
        let allSystem = ExerciseModel.mocks.allSatisfy(\.isSystemExercise)

        #expect(allSystem)
    }

    @Test("Test Seeded Workouts Resolve Their Exercises")
    func testSeededWorkoutsResolveTheirExercises() {
        #expect(!PrebuiltSeedData.workoutTemplates.isEmpty)
        for workout in PrebuiltSeedData.workoutTemplates {
            #expect(!workout.exercises.isEmpty, "\(workout.name) resolved no exercises")
        }
    }

    @Test("Test Mock Is One Of The Seeded Exercises")
    func testMockIsOneOfTheSeededExercises() {
        let isSeeded = ExerciseModel.mocks.map(\.id).contains(ExerciseModel.mock.id)

        #expect(isSeeded)
    }

    // MARK: - The user's own mocks

    @Test("Test User Mocks Are Not System Exercises")
    func testUserMocksAreNotSystemExercises() {
        let noneAreSystem = ExerciseModel.userMocks.allSatisfy { !$0.isSystemExercise }

        #expect(!ExerciseModel.userMocks.isEmpty)
        #expect(noneAreSystem)
    }

    @Test("Test User Mocks Share One Author")
    func testUserMocksShareOneAuthor() {
        #expect(Set(ExerciseModel.userMocks.map(\.authorId)).count == 1)
    }

    /// They exist to cover what the seeded library does not, so the two must not overlap.
    @Test("Test User Mocks Are Separate From The Seeded Library")
    func testUserMocksAreSeparateFromTheSeededLibrary() {
        let seeded = Set(ExerciseModel.mocks.map(\.id))
        let noOverlap = ExerciseModel.userMocks.allSatisfy { !seeded.contains($0.id) }

        #expect(noOverlap)
    }

    @Test("Test User Mocks Cover Metrics The Seeded Library Does Not")
    func testUserMocksCoverMetricsTheSeededLibraryDoesNot() {
        let metrics = Set(ExerciseModel.userMocks.flatMap(\.trackableMetrics))

        #expect(metrics.contains(.duration))
    }
}
