//
//  SetTargetPlanTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// A template's set plan: the new set types, and the plan fields every template saved before them
/// decodes without.
struct SetTargetPlanTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: Any) throws -> T {
        try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test("Test A Target Saved Before The Set Plan Decodes With No Plan")
    func testOldTargetDecodes() throws {
        let target = try decode(SetTarget.self, ["id": "t1", "set_number": 1, "min_reps": 8, "max_reps": 12, "set_type": "drop"])

        #expect(target.setType == .drop)
        #expect(target.dropCount == nil)
        #expect(target.dropStepPercent == nil)
        #expect(target.dropStep == 20)
        #expect(target.dropReps == nil)
        #expect(target.miniSetCount == nil)
        #expect(target.amrapTargetReps == nil)
    }

    @Test("Test A Set Plan Is Kept Through A Save Under Its Snake-Case Keys")
    func testPlanRoundTrips() throws {
        let target = SetTarget(
            id: "t1", setNumber: 2, setType: .drop,
            dropCount: 2, dropStepPercent: 30, dropReps: 6, miniSetCount: 3, amrapTargetReps: 8
        )
        let data = try JSONEncoder().encode(target)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["drop_count"] as? Int == 2)
        #expect(json["drop_step_percent"] as? Int == 30)
        #expect(json["drop_reps"] as? Int == 6)
        #expect(json["mini_set_count"] as? Int == 3)
        #expect(json["amrap_target_reps"] as? Int == 8)
        #expect(try JSONDecoder().decode(SetTarget.self, from: data) == target)
    }

    @Test("Test The New Set Types Round-Trip", arguments: [SetTargetSetType.amrap, .restPause, .cluster])
    func testNewSetTypesRoundTrip(setType: SetTargetSetType) throws {
        let data = try JSONEncoder().encode(SetTarget(setNumber: 1, setType: setType))

        #expect(try JSONDecoder().decode(SetTarget.self, from: data).setType == setType)
    }

    /// A "failure" set still decodes as itself, and both it and an AMRAP set are logged as AMRAP.
    @Test("Test Failure And AMRAP Targets Are Logged As AMRAP Sets")
    func testFailureReadsAsAMRAP() throws {
        let failure = try decode(SetTarget.self, ["id": "t1", "set_number": 1, "set_type": "failure"])

        #expect(failure.setType == .failure)
        #expect(SetKind(failure.setType) == .amrap)
        #expect(SetKind(.amrap) == .amrap)
        #expect(SetKind(.restPause) == .restPause)
        #expect(SetKind(.cluster) == .cluster)
    }

    @Test("Test A Set Type This Build Does Not Know Reads As Standard")
    func testUnknownSetTypeReadsAsStandard() throws {
        let target = try decode(SetTarget.self, ["id": "t1", "set_number": 1, "set_type": "giantSet"])

        #expect(target.setType == .standard)
    }
}
