//
//  ExerciseTemplateModelCodableAndProtocolTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 28/10/2025.
//

import Testing
import Foundation
@testable import Compound

/// What `ExerciseModel` promises the rest of the app: a stable identity, hashability, and decoding
/// that survives a stored document missing everything optional.
///
/// Its subject used to be `ExerciseModelModel`, replaced by `ExerciseModel` in the exercise
/// redesign. Construction and the encoded key names are covered in
/// `ExerciseModelInitializationTests`; this file keeps to the protocol conformances and to decoding
/// documents that are not fully populated, which is what Firestore actually returns for older
/// exercises.
@MainActor
struct ExerciseModelCodableAndProtocolTests {

    private func exercise(id: String = String.random, name: String = "Bench Press") -> ExerciseModel {
        ExerciseModel(
            id: id,
            authorId: "author-1",
            name: name,
            trackableMetrics: [.weight, .reps],
            type: .compoundUpper,
            laterality: .bilateral,
            muscleGroups: [.chest: .primary],
            isBodyweight: false,
            rangeOfMotion: 4,
            stability: 5,
            bodyWeightContribution: 0,
            alternateNames: []
        )
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    /// The required keys of a stored exercise, with every optional one left out.
    private var minimalJSON: [String: Any] {
        [
            "id": "exercise-1",
            "author_id": "author-1",
            "name": "Bench Press",
            "trackable_metrics": ["weight", "reps"],
            "muscle_groups": ["chest": "primary"],
            "is_bodyweight": false,
            "equipment_variations": [],
            "range_of_motion": 4,
            "stability": 5,
            "body_weight_contribution": 0,
            "alternate_names": [],
            "is_system_exercise": false,
            "date_created": 0,
            "date_modified": 0
        ]
    }

    // MARK: - Identifiable

    @Test("Test An Exercise Is Identified By Its Id")
    func testAnExerciseIsIdentifiedByItsId() {
        let id = String.random

        #expect(exercise(id: id).id == id)
    }

    // MARK: - Hashable

    @Test("Test Identical Exercises Hash Alike")
    func testIdenticalExercisesHashAlike() {
        let id = String.random
        let created = Date.random
        func make() -> ExerciseModel {
            ExerciseModel(
                id: id,
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

        #expect(make().hashValue == make().hashValue)
        #expect(Set([make(), make()]).count == 1)
    }

    @Test("Test Exercises With Different Ids Are Distinct")
    func testExercisesWithDifferentIdsAreDistinct() {
        let first = exercise(id: "exercise-1")
        let second = exercise(id: "exercise-2")

        #expect(first != second)
        #expect(Set([first, second]).count == 2)
    }

    // MARK: - Decoding

    @Test("Test Decoding An Exercise With No Optional Fields")
    func testDecodingAnExerciseWithNoOptionalFields() throws {
        let data = try JSONSerialization.data(withJSONObject: minimalJSON)

        let decoded = try decoder().decode(ExerciseModel.self, from: data)

        #expect(decoded.id == "exercise-1")
        #expect(decoded.name == "Bench Press")
        #expect(decoded.description == nil)
        #expect(decoded.imageURL == nil)
        #expect(decoded.type == nil)
        #expect(decoded.laterality == nil)
        #expect(decoded.muscleGroups == [.chest: .primary])
    }

    @Test("Test Decoding An Exercise With Some Optional Fields")
    func testDecodingAnExerciseWithSomeOptionalFields() throws {
        var json = minimalJSON
        json["description"] = "A horizontal press."
        json["type"] = "compoundUpper"
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try decoder().decode(ExerciseModel.self, from: data)

        #expect(decoded.description == "A horizontal press.")
        #expect(decoded.type == .compoundUpper)
        // Still absent, and still not a reason to fail.
        #expect(decoded.laterality == nil)
        #expect(decoded.imageURL == nil)
    }

    /// A case renamed without a migration would land here: the raw value no longer matches, and the
    /// whole exercise fails to decode rather than losing one field.
    @Test("Test Decoding Fails On An Unknown Enum Value")
    func testDecodingFailsOnAnUnknownEnumValue() throws {
        var json = minimalJSON
        json["trackable_metrics"] = ["weight", "notAMetric"]
        let data = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: DecodingError.self) {
            try decoder().decode(ExerciseModel.self, from: data)
        }
    }

    // MARK: - Image URL

    @Test("Test Updating The Image URL Replaces What Was There")
    func testUpdatingTheImageURLReplacesWhatWasThere() {
        var model = exercise()

        model.updateImageURL(imageUrl: "https://example.com/first.png")
        #expect(model.imageURL == "https://example.com/first.png")

        model.updateImageURL(imageUrl: "https://example.com/second.png")
        #expect(model.imageURL == "https://example.com/second.png")
    }
}
