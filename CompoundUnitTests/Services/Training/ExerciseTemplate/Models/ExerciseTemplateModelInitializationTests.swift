//
//  ExerciseTemplateModelInitializationTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 28/10/2025.
//

import Testing
import Foundation
@testable import Compound

/// Building an `ExerciseModel` and round-tripping it through `Codable`.
///
/// This file used to cover `ExerciseModelModel`, whose `type` was a single `ExerciseCategory` and
/// whose muscles were a flat `[MuscleGroup]`. An exercise now records what it measures
/// (`trackableMetrics`), its movement pattern (`type`), how it loads the body (`laterality`,
/// `isBodyweight`, `bodyWeightContribution`) and the muscles it works with each one's role.
@MainActor
struct ExerciseModelInitializationTests {

    private func exercise(
        id: String = String.random,
        name: String = "Bench Press",
        muscleGroups: [Muscles: MuscleTargetType] = [.chest: .primary, .triceps: .secondary],
        isSystemExercise: Bool = false
    ) -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "author-1",
            name: name,
            trackableMetrics: [.weight, .reps],
            type: .compoundUpper,
            laterality: .bilateral,
            muscleGroups: muscleGroups,
            isBodyweight: false,
            rangeOfMotion: 4,
            stability: 5,
            bodyWeightContribution: 0,
            alternateNames: ["Barbell Bench Press"],
            isSystemExercise: isSystemExercise
        )
    }

    // MARK: - Initialization

    @Test("Test Initialization Keeps What It Was Given")
    func testInitializationKeepsWhatItWasGiven() {
        let model = exercise(id: "exercise-1", name: "Bench Press")

        #expect(model.id == "exercise-1")
        #expect(model.authorId == "author-1")
        #expect(model.name == "Bench Press")
        #expect(model.trackableMetrics == [.weight, .reps])
        #expect(model.type == .compoundUpper)
        #expect(model.laterality == .bilateral)
        #expect(model.isBodyweight == false)
        #expect(model.rangeOfMotion == 4)
        #expect(model.stability == 5)
        #expect(model.bodyWeightContribution == 0)
        #expect(model.alternateNames == ["Barbell Bench Press"])
    }

    @Test("Test Defaults For What Was Not Given")
    func testDefaultsForWhatWasNotGiven() {
        let model = exercise()

        #expect(model.description == nil)
        #expect(model.imageURL == nil)
        #expect(model.equipmentVariations.isEmpty)
        #expect(model.isSystemExercise == false)
        #expect(model.clickCount == 0)
        #expect(model.bookmarkCount == 0)
        #expect(model.favouriteCount == 0)
    }

    @Test("Test An Exercise Gets An Id When None Is Given")
    func testAnExerciseGetsAnIdWhenNoneIsGiven() {
        let first = ExerciseModel(
            authorId: "author-1",
            name: "Squat",
            trackableMetrics: [.weight, .reps],
            type: .compoundLower,
            laterality: .bilateral,
            muscleGroups: [.quads: .primary],
            isBodyweight: false,
            rangeOfMotion: 4,
            stability: 4,
            bodyWeightContribution: 0,
            alternateNames: []
        )
        let second = ExerciseModel(
            authorId: "author-1",
            name: "Squat",
            trackableMetrics: [.weight, .reps],
            type: .compoundLower,
            laterality: .bilateral,
            muscleGroups: [.quads: .primary],
            isBodyweight: false,
            rangeOfMotion: 4,
            stability: 4,
            bodyWeightContribution: 0,
            alternateNames: []
        )

        #expect(!first.id.isEmpty)
        #expect(first.id != second.id)
    }

    // MARK: - Muscles

    /// A muscle is recorded with the part it plays, so a chart of what an exercise works can weigh
    /// the prime mover against the supporting muscles.
    @Test("Test Muscles Carry Their Role")
    func testMusclesCarryTheirRole() {
        let model = exercise(muscleGroups: [.chest: .primary, .triceps: .secondary, .frontDelts: .secondary])

        #expect(model.muscleGroups[.chest] == .primary)
        #expect(model.muscleGroups[.triceps] == .secondary)
        #expect(model.muscleGroups[.frontDelts] == .secondary)
        #expect(model.muscleGroups.filter { $0.value == .primary }.count == 1)
    }

    @Test("Test An Exercise Can Work Any Muscle")
    func testAnExerciseCanWorkAnyMuscle() {
        for muscle in Muscles.allCases {
            let model = exercise(muscleGroups: [muscle: .primary])
            #expect(model.muscleGroups[muscle] == .primary)
        }
    }

    @Test("Test An Exercise Can Have No Muscles Recorded")
    func testAnExerciseCanHaveNoMusclesRecorded() {
        #expect(exercise(muscleGroups: [:]).muscleGroups.isEmpty)
    }

    // MARK: - Codable

    @Test("Test Encoding And Decoding Round Trips")
    func testEncodingAndDecodingRoundTrips() throws {
        let original = exercise(id: "exercise-1", name: "Bench Press")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(ExerciseModel.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.authorId == original.authorId)
        #expect(decoded.trackableMetrics == original.trackableMetrics)
        #expect(decoded.type == original.type)
        #expect(decoded.laterality == original.laterality)
        #expect(decoded.muscleGroups == original.muscleGroups)
        #expect(decoded.isBodyweight == original.isBodyweight)
        #expect(decoded.rangeOfMotion == original.rangeOfMotion)
        #expect(decoded.alternateNames == original.alternateNames)
    }

    /// Firestore reads these keys, so they are part of the stored shape rather than an internal
    /// detail.
    @Test("Test Coding Keys Are Snake Case")
    func testCodingKeysAreSnakeCase() throws {
        let model = exercise(id: "exercise-1", isSystemExercise: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(model)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["id"] as? String == "exercise-1")
        #expect(json?["author_id"] as? String == "author-1")
        #expect(json?["trackable_metrics"] as? [String] == ["weight", "reps"])
        #expect(json?["is_bodyweight"] as? Bool == false)
        #expect(json?["is_system_exercise"] as? Bool == true)
        #expect(json?["range_of_motion"] as? Int == 4)
        #expect(json?["body_weight_contribution"] as? Int == 0)
        #expect(json?["alternate_names"] as? [String] == ["Barbell Bench Press"])
        #expect(json?["muscle_groups"] as? [String: String] == ["chest": "primary", "triceps": "secondary"])
    }

    // MARK: - Identity

    @Test("Test Exercises Are Equal When Their Contents Match")
    func testExercisesAreEqualWhenTheirContentsMatch() {
        let created = Date.random
        func make() -> ExerciseModel {
            ExerciseModel(
                id: "exercise-1",
                authorId: "author-1",
                name: "Bench Press",
                trackableMetrics: [.weight, .reps],
                type: .compoundUpper,
                laterality: .bilateral,
                muscleGroups: [.chest: .primary],
                isBodyweight: false,
                rangeOfMotion: 4,
                stability: 5,
                bodyWeightContribution: 0,
                alternateNames: [],
                dateCreated: created,
                dateModified: created
            )
        }

        #expect(make() == make())
    }
}
