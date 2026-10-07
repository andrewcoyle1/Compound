//
//  WorkoutSessionPlanFieldsTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The plan's per-exercise columns on a session exercise.
@MainActor
struct WorkoutSessionPlanFieldsTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Session exercise coding

    private func sessionExercise() -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "exercise-1",
            authorId: "author-1",
            templateId: "library-1",
            name: "Bench Press",
            trackingMode: .weightReps,
            index: 1,
            notes: "Felt strong",
            sets: []
        )
    }

    @Test("Test A Session Exercise Saved Before The Plan Fields Decodes With Them Empty")
    func testAnOldSessionExerciseDecodes() throws {
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(sessionExercise())) as? [String: Any] ?? [:]
        #expect(json["plan_notes"] == nil)
        #expect(json["substitute_exercise_ids"] == nil)
        json.removeValue(forKey: "set_targets")
        json.removeValue(forKey: "equipment_variations")

        let decoded = try JSONDecoder().decode(WorkoutExerciseModel.self, from: JSONSerialization.data(withJSONObject: json))

        #expect(decoded == sessionExercise())
        #expect(decoded.notes == "Felt strong")
        #expect(decoded.planNotes == nil)
        #expect(decoded.restSeconds == nil)
        #expect(decoded.linkURL == nil)
        #expect(decoded.substituteExerciseIds.isEmpty)
    }

    @Test("Test The Plan Fields Round-Trip Beside The User's Own Notes")
    func testThePlanFieldsRoundTrip() throws {
        var original = sessionExercise()
        original.planNotes = "Pause at the bottom"
        original.restSeconds = 120
        original.linkURL = "https://example.com/video"
        original.substituteExerciseIds = ["sub-1"]

        let data = try JSONEncoder().encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        #expect(try JSONDecoder().decode(WorkoutExerciseModel.self, from: data) == original)
        #expect(json["plan_notes"] as? String == "Pause at the bottom")
        #expect(json["rest_seconds"] as? Int == 120)
        #expect(json["link_url"] as? String == "https://example.com/video")
        #expect(json["substitute_exercise_ids"] as? [String] == ["sub-1"])
        #expect(json["notes"] as? String == "Felt strong")
    }
}
