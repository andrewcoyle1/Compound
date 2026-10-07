//
//  SetKindTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 07/10/2026.
//

import Testing
import Foundation
@testable import Compound

/// Set kinds and sub-sets: every set saved before them still reads, a kind this build does not
/// know reads as standard, and a drop or mini-set is part of its parent rather than a set.
@MainActor
struct SetKindTests {

    private let date = Date(timeIntervalSince1970: 1_000_000)

    private func set(
        _ id: String,
        kind: SetKind = .standard,
        parent: String? = nil,
        side: SetSide? = nil,
        completed: Bool = true
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: 1, reps: 8, weightKg: 100, side: side,
            kind: kind, parentSetId: parent, isWarmup: false, completedAt: completed ? date : nil, dateCreated: date
        )
    }

    private func json(_ set: WorkoutSetModel) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(set)) as? [String: Any])
    }

    private func decode(_ json: [String: Any]) throws -> WorkoutSetModel {
        try JSONDecoder().decode(WorkoutSetModel.self, from: JSONSerialization.data(withJSONObject: json))
    }

    // MARK: - Decoding

    @Test("Test A Set Saved Before Kinds Existed Decodes As A Standard Set Of Its Own")
    func testASetSavedBeforeKindsDecodes() throws {
        var json = try json(set("s1"))
        json.removeValue(forKey: "kind")
        json.removeValue(forKey: "parent_set_id")

        let decoded = try decode(json)

        #expect(decoded.kind == .standard)
        #expect(decoded.parentSetId == nil)
        #expect(!decoded.isSubSet)
    }

    @Test("Test An Unknown Kind Reads As Standard")
    func testAnUnknownKindReadsAsStandard() throws {
        var json = try json(set("s1"))
        json["kind"] = "giantSet"

        #expect(try decode(json).kind == .standard)
    }

    @Test("Test Kind And Parent Round-Trip Under Their Firestore Keys")
    func testKindAndParentRoundTrip() throws {
        for kind in SetKind.allCases {
            let original = set("s2", kind: kind, parent: "s1")
            let json = try json(original)

            #expect(json["kind"] as? String == (kind == .standard ? nil : kind.rawValue))
            #expect(json["parent_set_id"] as? String == "s1")
            let decoded = try decode(json)
            #expect(decoded.kind == kind)
            #expect(decoded.parentSetId == "s1")
            #expect(decoded == original)
        }
    }

    @Test("Test A Template's Set Type Maps To A Kind")
    func testATemplatesSetTypeMapsToAKind() {
        #expect(SetKind(.standard) == .standard)
        #expect(SetKind(.drop) == .drop)
        #expect(SetKind(.myo) == .myo)
        #expect(SetKind(.failure) == .amrap)
    }
}
