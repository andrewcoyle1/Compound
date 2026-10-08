//
//  WorkoutTemplateExerciseDecodingTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The plan's per-exercise columns on a template exercise: every template saved before them still
/// decodes, they survive a save, and a microcycle finds its own targets.
struct WorkoutTemplateExerciseDecodingTests {

    private func targets(_ count: Int, reps: Int = 8) -> [SetTarget] {
        (1...count).map { SetTarget(id: "target-\(count)-\($0)", setNumber: $0, minReps: reps, maxReps: reps + 2) }
    }

    /// Fixed dates, so two builds of it are equal.
    private let library = ExerciseModel(
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
        dateCreated: Date(timeIntervalSince1970: 1_000_000),
        dateModified: Date(timeIntervalSince1970: 1_000_000)
    )

    private func exercise(overrides: [MicrocycleSetTargets] = []) -> WorkoutTemplateExercise {
        WorkoutTemplateExercise(
            id: "template-exercise-1",
            exercise: library,
            setTargets: targets(2),
            setRestTimers: false,
            setTargetsByMicrocycle: overrides
        )
    }

    // MARK: - Decoding

    @Test("Test A Document With Only The Four Original Keys Decodes With Every Plan Field Empty")
    func testAnOldDocumentDecodes() throws {
        let full = try JSONSerialization.jsonObject(with: JSONEncoder().encode(exercise())) as? [String: Any] ?? [:]
        let old = full.filter { ["id", "exercise", "set_targets", "set_rest_timers"].contains($0.key) }
        #expect(old.count == 4)

        let decoded = try JSONDecoder().decode(WorkoutTemplateExercise.self, from: JSONSerialization.data(withJSONObject: old))

        #expect(decoded == exercise())
        #expect(decoded.notes == nil)
        #expect(decoded.warmupSetCount == nil)
        #expect(decoded.restSeconds == nil)
        #expect(decoded.substituteExerciseIds.isEmpty)
        #expect(decoded.supersetGroupId == nil)
        #expect(decoded.linkURL == nil)
        #expect(decoded.setTargetsByMicrocycle.isEmpty)
    }

    /// Nothing set means nothing written, so a template without a plan reads as it always has.
    @Test("Test Empty Plan Fields Are Not Written")
    func testEmptyPlanFieldsAreNotWritten() throws {
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(exercise())) as? [String: Any] ?? [:]

        #expect(Set(json.keys) == ["id", "exercise", "set_targets", "set_rest_timers"])
    }

    @Test("Test Every Plan Field Round-Trips Under Its Snake-Case Key")
    func testEveryPlanFieldRoundTrips() throws {
        var original = exercise(overrides: [MicrocycleSetTargets(fromMicrocycle: 2, setTargets: targets(3))])
        original.notes = "Pause at the bottom"
        original.warmupSetCount = 3
        original.restSeconds = 150
        original.substituteExerciseIds = ["sub-1", "sub-2"]
        original.supersetGroupId = "group-a"
        original.linkURL = "https://example.com/video"

        let data = try JSONEncoder().encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let decoded = try JSONDecoder().decode(WorkoutTemplateExercise.self, from: data)

        #expect(decoded == original)
        #expect(Set(json.keys).isSuperset(of: [
            "notes", "warmup_set_count", "rest_seconds", "substitute_exercise_ids",
            "superset_group_id", "link_url", "set_targets_by_microcycle"
        ]))
        let override = (json["set_targets_by_microcycle"] as? [[String: Any]])?.first
        #expect(override?["from_microcycle"] as? Int == 2)
        #expect((override?["set_targets"] as? [Any])?.count == 3)
    }

    // MARK: - Targets by microcycle

    @Test("Test Microcycle Targets Pick The Latest Override That Has Started")
    func testMicrocycleTargetsPickTheLatestOverride() {
        let weekTwo = targets(3)
        let weekNine = targets(4)
        // Out of order on purpose: the lookup must not rely on the list being sorted.
        let model = exercise(overrides: [
            MicrocycleSetTargets(fromMicrocycle: 9, setTargets: weekNine),
            MicrocycleSetTargets(fromMicrocycle: 2, setTargets: weekTwo)
        ])

        #expect(model.setTargets(forMicrocycle: nil) == targets(2))
        #expect(model.setTargets(forMicrocycle: 0) == targets(2))
        #expect(model.setTargets(forMicrocycle: -3) == targets(2))
        #expect(model.setTargets(forMicrocycle: 1) == targets(2))
        #expect(model.setTargets(forMicrocycle: 2) == weekTwo)
        #expect(model.setTargets(forMicrocycle: 5) == weekTwo)
        #expect(model.setTargets(forMicrocycle: 9) == weekNine)
        #expect(model.setTargets(forMicrocycle: 30) == weekNine)
    }

    @Test("Test Without Overrides Every Microcycle Is The Base")
    func testWithoutOverridesEveryMicrocycleIsTheBase() {
        #expect(exercise().setTargets(forMicrocycle: 4) == targets(2))
    }
}
