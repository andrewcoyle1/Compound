//
//  FirestoreContractTests+Programs.swift
//  CompoundUnitTests
//
//  Mesocycles (`users/{uid}/mesocycles`, also the payload of a mesocycle share), macrocycles
//  (`users/{uid}/macrocycles`) and the food library (`users/{uid}/foods`) under the Firestore
//  contract. All three decode with Swift's synthesized decoder, so their only lenient paths are
//  null optionals and keys a model no longer has. See FirestoreContractTests.swift.
//

import Foundation
import Testing
import FirebaseFirestore
@testable import Compound

extension FirestoreContractTests {

    /// None of these is updated field by field: each manager saves whole documents, which merge.
    /// The named fields are `author_id`, which the rules check on every write, and what
    /// `get_plan` in `functions/coach.js` reads by name.
    static func programAndFoodContracts() throws -> [Contract] {
        [
            try contract(
                Mesocycle.self, directory: "mesocycle",
                full: Samples.fullMesocycle, minimal: Samples.minimalMesocycle,
                namedFields: ([
                    .id, .authorId, .name, .numMicrocycles, .deload, .workoutTemplates
                ] as [Mesocycle.CodingKeys]).map(\.rawValue)
            ),
            try contract(
                Macrocycle.self, directory: "macrocycle",
                full: Samples.fullMacrocycle, minimal: Samples.minimalMacrocycle,
                namedFields: ([
                    .authorId, .name, .mesocycleIds, .status, .mesocycleIndex, .mesocycleStartedAt, .skips,
                    .dateModified
                ] as [Macrocycle.CodingKeys]).map(\.rawValue)
            ),
            try contract(
                FoodModel.self, directory: "food_model",
                full: Samples.fullFood, minimal: Samples.minimalFood,
                namedFields: [FoodModel.CodingKeys.authorId.rawValue]
            )
        ]
    }

    /// Exhaustive, as in `enumRawValuesMatch`.
    static func programAndFoodEnums() -> [String: [String]] {
        // Not CaseIterable.
        let statuses: [Macrocycle.Status] = [.notStarted, .active, .completed, .ended]
        for status in statuses {
            switch status {
            case .notStarted, .active, .completed, .ended: break
            }
        }
        return [
            "DeloadType": DeloadType.allCases.map(\.rawValue),
            "MacrocycleStatus": statuses.map(\.rawValue),
            "MeasurementMethod": MeasurementMethod.allCases.map(\.rawValue)
        ]
    }

    @Test("A skip's fields are what get_plan in functions/coach.js reads")
    func cycleSkipFieldsAreInFullFixture() throws {
        let fixture = try Self.taggedFixture("macrocycle", "full")
        let skips = try #require(fixture["skips"] as? [[String: Any]])
        let keys = Set(try #require(skips.first).keys)
        for field in ["mesocycle_index", "cycle_index", "position", "template_id"] {
            #expect(keys.contains(field), "macrocycle skips: \(field) is not in full.json")
        }
    }
}
