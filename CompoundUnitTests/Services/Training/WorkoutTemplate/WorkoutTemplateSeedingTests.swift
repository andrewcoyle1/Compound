//
//  WorkoutTemplateSeedingTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// Seeding the shipped workout library.
///
/// The prebuilt workouts are stored as exercise *ids*, so a workout can only be built once the
/// exercise library exists — which is why `CoreInteractor.logIn()` seeds exercises first and
/// hands the result to this manager. Seeding is then gated on two `UserDefaults` flags, and
/// those flags are the dangerous part: once they say "done", the library is never rebuilt until
/// the version is bumped.
///
/// Each test gets `UserDefaults` of its own rather than `.standard`, so the flags here cannot
/// collide with the developer-menu tests, which assert on the same four literal keys.
@MainActor
struct WorkoutTemplateSeedingTests {

    /// The six exercises `workout-push-1` is built from. Seeding with these builds every prebuilt
    /// workout that uses at least one of them, and skips the rest.
    private var pushExercises: [ExerciseModel] {
        [
            "system-barbell-bench-press",
            "system-barbell-incline-bench-press",
            "system-cable-pushdown-straight-bar",
            "system-dumbbell-seated-shoulder-press",
            "system-overhead-extension-straight-bar",
            "system-standing-lateral-raise-cable"
        ].map { exercise(id: $0) }
    }

    /// Three exercises no prebuilt push workout uses, for proving a reseed replaces rather than
    /// adds to what is already there.
    private var pullExercises: [ExerciseModel] {
        ["system-t-bar-row", "system-seated-row", "system-lat-prayer-straight-bar"].map { exercise(id: $0) }
    }

    private func exercise(id: String) -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "official",
            name: id,
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
            isSystemExercise: true
        )
    }

    private func makeManager() -> (WorkoutTemplateManager, UserDefaults) {
        let defaults = TestManagers.scratchDefaults()
        return (TestManagers.workoutTemplateManager(userDefaults: defaults), defaults)
    }

    // MARK: - First run

    @Test("Test The First Run Seeds The Shipped Workouts")
    func testTheFirstRunSeedsTheShippedWorkouts() throws {
        let (manager, _) = makeManager()
        #expect(manager.systemWorkoutTemplates.isEmpty)

        try manager.seedWorkoutTemplatesIfNeeded(exercises: pushExercises)

        let pushDay = manager.systemWorkoutTemplates.first(where: { $0.id == "workout-push-1" })
        #expect(pushDay?.name == "Push Day A")
        #expect(pushDay?.exercises.count == pushExercises.count)
        // Seeded workouts are the app's, not the user's — nothing here is attributed to a person.
        #expect(manager.systemWorkoutTemplates.allSatisfy { $0.authorId == "official" })
        #expect(manager.hasSeeded)
    }

    /// A prebuilt workout whose exercises are all missing is dropped rather than seeded empty —
    /// an exercise-less workout would show in the library as a rest day.
    @Test("Test A Workout Whose Exercises Are Missing Is Not Seeded")
    func testAWorkoutWhoseExercisesAreMissingIsNotSeeded() throws {
        let (manager, _) = makeManager()

        try manager.seedWorkoutTemplatesIfNeeded(exercises: pushExercises)

        #expect(!manager.systemWorkoutTemplates.map(\.id).contains("workout-pull-1"))
        #expect(manager.systemWorkoutTemplates.allSatisfy { !$0.exercises.isEmpty })
    }

    // MARK: - The flags

    @Test("Test A Second Run Does Not Seed Again")
    func testASecondRunDoesNotSeedAgain() throws {
        let (manager, _) = makeManager()
        try manager.seedWorkoutTemplatesIfNeeded(exercises: pushExercises)
        let seeded = manager.systemWorkoutTemplates.map(\.id).sorted()
        #expect(!seeded.isEmpty)

        // A second call with nothing to build from: had the guard not held, the library would be
        // cleared and rebuilt as empty.
        try manager.seedWorkoutTemplatesIfNeeded(exercises: [])

        #expect(manager.systemWorkoutTemplates.map(\.id).sorted() == seeded)
    }

    @Test("Test An Older Seeding Version Is Reseeded")
    func testAnOlderSeedingVersionIsReseeded() throws {
        let (manager, defaults) = makeManager()
        // The state left by an install that seeded under an earlier version of the shipped file.
        defaults.set(true, forKey: "hasSeededPrebuiltWorkouts")
        defaults.set(1, forKey: "prebuiltWorkoutsSeedingVersion")
        #expect(manager.systemWorkoutTemplates.isEmpty)

        try manager.seedWorkoutTemplatesIfNeeded(exercises: pushExercises)

        #expect(!manager.systemWorkoutTemplates.isEmpty)
        #expect(manager.seedingVersion > 1)
    }

    @Test("Test Reseeding Replaces The Library Rather Than Adding To It")
    func testReseedingReplacesTheLibrary() throws {
        let (manager, _) = makeManager()
        try manager.seedWorkoutTemplatesIfNeeded(exercises: pushExercises)
        #expect(manager.systemWorkoutTemplates.map(\.id).contains("workout-push-1"))

        // The developer menu's reset, and what a version bump does: clear, then insert. Seeding
        // from a different set of exercises must not leave the previous set behind.
        try manager.resetAndReseedWorkoutTemplates(exercises: pullExercises)

        #expect(manager.systemWorkoutTemplates.map(\.id).contains("workout-pull-1"))
        #expect(!manager.systemWorkoutTemplates.map(\.id).contains("workout-push-1"))
    }

    /// The trap the seeding order exists to avoid: the exercise library has to be loaded first,
    /// and a call made before it is holds no exercises at all. Marking the library seeded on that
    /// call would leave the install with no prebuilt workouts until the next version bump.
    @Test("Test Seeding With No Exercises Does Not Mark The Library As Seeded")
    func testSeedingWithNoExercisesDoesNotMarkTheLibraryAsSeeded() throws {
        let (manager, _) = makeManager()

        try manager.seedWorkoutTemplatesIfNeeded(exercises: [])

        #expect(manager.systemWorkoutTemplates.isEmpty)
        #expect(!manager.hasSeeded)

        // …and the next call, once the exercises are there, still seeds.
        try manager.seedWorkoutTemplatesIfNeeded(exercises: pushExercises)
        #expect(!manager.systemWorkoutTemplates.isEmpty)
    }

    /// The same call at a version bump is worse: it clears the library it is about to fail to
    /// rebuild.
    @Test("Test Seeding With No Exercises Does Not Clear What Was Already Seeded")
    func testSeedingWithNoExercisesDoesNotClearWhatWasAlreadySeeded() throws {
        let (manager, defaults) = makeManager()
        try manager.seedWorkoutTemplatesIfNeeded(exercises: pushExercises)
        let seeded = manager.systemWorkoutTemplates.map(\.id).sorted()
        // Reopen the gate the way a shipped version bump does.
        defaults.set(1, forKey: "prebuiltWorkoutsSeedingVersion")

        try manager.seedWorkoutTemplatesIfNeeded(exercises: [])

        #expect(manager.systemWorkoutTemplates.map(\.id).sorted() == seeded)
    }
}
