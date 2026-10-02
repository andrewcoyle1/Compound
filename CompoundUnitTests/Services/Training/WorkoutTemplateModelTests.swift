//
//  WorkoutTemplateModelTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// A saved workout: the plan a session is started from.
///
/// Its `eventParameters` are what every workout analytics event is built from, and they drop nil
/// values — so an event's shape depends on how complete the template is. That is easy to break
/// without noticing, because analytics failures are silent.
@MainActor
struct WorkoutTemplateModelTests {

    private let date = Date(timeIntervalSince1970: 1_000_000)

    private func template(
        name: String = "Push Day",
        description: String? = nil,
        gymProfileId: String? = nil,
        imageURL: String? = nil,
        exercises: [WorkoutTemplateExercise] = []
    ) -> WorkoutTemplateModel {
        WorkoutTemplateModel(
            id: "workout-1",
            authorId: "author-1",
            name: name,
            description: description,
            gymProfileId: gymProfileId,
            imageURL: imageURL,
            dateCreated: date,
            dateModified: date,
            exercises: exercises
        )
    }

    // MARK: - Identity

    @Test("Test A Template Is Identified By Its Workout Id")
    func testATemplateIsIdentifiedByItsWorkoutId() {
        let template = template()

        #expect(template.id == "workout-1")
        #expect(template.id == template.workoutId)
    }

    @Test("Test A Template Gets An Id When None Is Given")
    func testATemplateGetsAnIdWhenNoneIsGiven() {
        let first = WorkoutTemplateModel(authorId: "a", name: "Push")
        let second = WorkoutTemplateModel(authorId: "a", name: "Push")

        #expect(!first.id.isEmpty)
        #expect(first.id != second.id)
    }

    @Test("Test A New Template Has No Exercises Or Artwork")
    func testANewTemplateHasNoExercisesOrArtwork() {
        let template = WorkoutTemplateModel(authorId: "a", name: "Push")

        #expect(template.exercises.isEmpty)
        #expect(template.imageURL == nil)
        #expect(template.description == nil)
        #expect(template.gymProfileId == nil)
    }

    @Test("Test Updating The Image URL Replaces It")
    func testUpdatingTheImageURLReplacesIt() {
        var template = template()

        template.updateImageURL(imageUrl: "https://example.com/push.png")

        #expect(template.imageURL == "https://example.com/push.png")
    }

    // MARK: - Analytics parameters

    @Test("Test Event Parameters Are Prefixed And Snake Case")
    func testEventParametersArePrefixedAndSnakeCase() {
        let parameters = template().eventParameters

        #expect(parameters["workout_workout_id"] as? String == "workout-1")
        #expect(parameters["workout_author_id"] as? String == "author-1")
        #expect(parameters["workout_name"] as? String == "Push Day")
    }

    /// A template with nothing optional filled in logs only the keys it has, rather than a row of
    /// nulls.
    @Test("Test Event Parameters Leave Out What Is Not Set")
    func testEventParametersLeaveOutWhatIsNotSet() {
        let parameters = template().eventParameters

        #expect(parameters["workout_description"] == nil)
        #expect(parameters["workout_gym_profile_id"] == nil)
        #expect(parameters["workout_image_url"] == nil)
    }

    @Test("Test Event Parameters Include What Is Set")
    func testEventParametersIncludeWhatIsSet() {
        let parameters = template(
            description: "Chest and shoulders",
            gymProfileId: "gym-1",
            imageURL: "https://example.com/push.png"
        ).eventParameters

        #expect(parameters["workout_description"] as? String == "Chest and shoulders")
        #expect(parameters["workout_gym_profile_id"] as? String == "gym-1")
        #expect(parameters["workout_image_url"] as? String == "https://example.com/push.png")
    }

    /// The exercises are logged as ids, not whole objects, which is what keeps an event small
    /// enough to send.
    @Test("Test Event Parameters Log Exercises As Ids")
    func testEventParametersLogExercisesAsIds() {
        let exercises = PrebuiltSeedData.workoutTemplates.first?.exercises ?? []
        let parameters = template(exercises: exercises).eventParameters
        let logged = parameters["workout_exercises"] as? [String]

        #expect(logged?.count == exercises.count)
        #expect(logged == exercises.map(\.id))
    }

    // MARK: - Codable

    @Test("Test A Template Round Trips")
    func testATemplateRoundTrips() throws {
        let original = template(description: "Chest and shoulders", gymProfileId: "gym-1")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(WorkoutTemplateModel.self, from: data)

        #expect(decoded.workoutId == original.workoutId)
        #expect(decoded.name == original.name)
        #expect(decoded.description == original.description)
        #expect(decoded.gymProfileId == original.gymProfileId)
    }

    @Test("Test The Encoded Keys Are Snake Case")
    func testTheEncodedKeysAreSnakeCase() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(template())
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["workout_id"] as? String == "workout-1")
        #expect(json?["author_id"] as? String == "author-1")
        #expect(json?["date_created"] != nil)
    }
}

/// The workouts a new account is seeded with, read from `PrebuiltWorkouts.json`.
///
/// They are resolved against the seeded exercise library by id, so a workout naming an exercise
/// that is not there loses it silently — `compactMap` drops it. That makes an empty or short
/// workout the symptom of a mismatch between the two JSON files.
@MainActor
struct PrebuiltWorkoutSeedDataTests {

    @Test("Test The Seeded Workouts Decode")
    func testTheSeededWorkoutsDecode() {
        #expect(!PrebuiltSeedData.workoutTemplates.isEmpty)
    }

    @Test("Test Every Seeded Workout Is Named And Has Exercises")
    func testEverySeededWorkoutIsNamedAndHasExercises() {
        for workout in PrebuiltSeedData.workoutTemplates {
            #expect(!workout.name.isEmpty)
            #expect(!workout.exercises.isEmpty, "\(workout.name) has no exercises")
        }
    }

    /// Each exercise in a seeded workout must resolve to one in the seeded library, or it was
    /// dropped on the way in.
    @Test("Test Seeded Workouts Only Reference Seeded Exercises")
    func testSeededWorkoutsOnlyReferenceSeededExercises() {
        let library = Set(ExerciseModel.mocks.map(\.id))

        for workout in PrebuiltSeedData.workoutTemplates {
            for exercise in workout.exercises {
                #expect(library.contains(exercise.exercise.id), "\(workout.name) references \(exercise.exercise.id)")
            }
        }
    }

    @Test("Test Seeded Workout Ids Are Unique")
    func testSeededWorkoutIdsAreUnique() {
        let ids = PrebuiltSeedData.workoutTemplates.map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    @Test("Test Looking Up A Seeded Exercise By Id")
    func testLookingUpASeededExerciseById() throws {
        let known = try #require(ExerciseModel.mocks.first)

        #expect(PrebuiltSeedData.exercise(id: known.id)?.name == known.name)
        #expect(PrebuiltSeedData.exercise(id: "not-a-real-id") == nil)
    }
}
