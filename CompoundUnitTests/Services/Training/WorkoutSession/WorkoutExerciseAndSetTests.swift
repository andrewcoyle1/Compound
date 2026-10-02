//
//  WorkoutExerciseAndSetTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The two pieces a logged workout is built from: an exercise and the sets under it.
///
/// `WorkoutExerciseModel` writes its own `Codable` by hand rather than taking the synthesised one,
/// which is where a field gets forgotten — so the round trip here is load-bearing. Three of its
/// properties were added after the model shipped and decode with a fallback, so a session saved
/// before they existed still opens.
@MainActor
struct WorkoutExerciseModelTests {

    private let date = Date(timeIntervalSince1970: 1_000_000)

    private func set(index: Int, isWarmup: Bool = false, completed: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-\(index)",
            authorId: "author-1",
            index: index,
            reps: 8,
            weightKg: 60,
            isWarmup: isWarmup,
            completedAt: completed ? date : nil,
            dateCreated: date
        )
    }

    private func exercise(sets: [WorkoutSetModel], targets: [SetTarget] = []) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "exercise-1",
            authorId: "author-1",
            templateId: "system-barbell-bench-press",
            name: "Bench Press",
            trackingMode: .weightReps,
            index: 1,
            sets: sets,
            setTargets: targets
        )
    }

    // MARK: - Counting completed sets

    /// The progress a user sees mid-workout. Warm-ups are deliberately not counted: finishing three
    /// warm-ups is not three sets of work done.
    @Test("Test Only Finished Working Sets Are Counted")
    func testOnlyFinishedWorkingSetsAreCounted() {
        let exercise = exercise(sets: [
            set(index: 1, isWarmup: true, completed: true),
            set(index: 2, completed: true),
            set(index: 3, completed: true),
            set(index: 4)
        ])

        #expect(exercise.completedSetsCount == 2)
    }

    @Test("Test Nothing Finished Counts As None")
    func testNothingFinishedCountsAsNone() {
        #expect(exercise(sets: [set(index: 1), set(index: 2)]).completedSetsCount == 0)
        #expect(exercise(sets: []).completedSetsCount == 0)
    }

    @Test("Test Warm-Ups Alone Count As None")
    func testWarmUpsAloneCountAsNone() {
        let exercise = exercise(sets: [
            set(index: 1, isWarmup: true, completed: true),
            set(index: 2, isWarmup: true, completed: true)
        ])

        #expect(exercise.completedSetsCount == 0)
    }

    // MARK: - Defaults

    @Test("Test An Exercise Defaults To No Targets Or Variations")
    func testAnExerciseDefaultsToNoTargetsOrVariations() {
        let exercise = exercise(sets: [set(index: 1)])

        #expect(exercise.setTargets.isEmpty)
        #expect(exercise.equipmentVariations.isEmpty)
        #expect(exercise.chosenVariationId == nil)
        #expect(exercise.supersetGroupId == nil)
        #expect(exercise.notes == nil)
    }

    // MARK: - Codable

    @Test("Test An Exercise Round Trips")
    func testAnExerciseRoundTrips() throws {
        let original = exercise(
            sets: [set(index: 1, isWarmup: true), set(index: 2, completed: true)],
            targets: [SetTarget(setNumber: 1, minReps: 6, maxReps: 10)]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(WorkoutExerciseModel.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.templateId == original.templateId)
        #expect(decoded.trackingMode == original.trackingMode)
        #expect(decoded.index == original.index)
        #expect(decoded.sets.count == 2)
        #expect(decoded.sets.map(\.index) == [1, 2])
        #expect(decoded.sets[0].isWarmup)
        #expect(decoded.setTargets.count == 1)
    }

    /// A session logged before set targets, equipment variations and supersets existed has none of
    /// those keys. It must still open, with empty collections rather than a decoding failure.
    @Test("Test An Older Session Decodes Without The Newer Fields")
    func testAnOlderSessionDecodesWithoutTheNewerFields() throws {
        let json: [String: Any] = [
            "id": "exercise-1",
            "author_id": "author-1",
            "template_id": "system-barbell-bench-press",
            "name": "Bench Press",
            "tracking_mode": TrackingMode.weightReps.rawValue,
            "index": 1,
            "sets": []
        ]
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(WorkoutExerciseModel.self, from: data)

        #expect(decoded.setTargets.isEmpty)
        #expect(decoded.equipmentVariations.isEmpty)
        #expect(decoded.supersetGroupId == nil)
        #expect(decoded.notes == nil)
    }

    @Test("Test The Encoded Keys Are Snake Case")
    func testTheEncodedKeysAreSnakeCase() throws {
        let data = try JSONEncoder().encode(exercise(sets: []))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["template_id"] as? String == "system-barbell-bench-press")
        #expect(json?["tracking_mode"] != nil)
        #expect(json?["set_targets"] != nil)
    }
}

/// A single logged set.
@MainActor
struct WorkoutSetModelTests {

    private let date = Date(timeIntervalSince1970: 1_000_000)

    private func set(
        reps: Int? = nil,
        weightKg: Double? = nil,
        durationSec: Int? = nil,
        distanceMeters: Double? = nil,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        completedAt: Date? = nil
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: "set-1",
            authorId: "author-1",
            index: 1,
            reps: reps,
            weightKg: weightKg,
            durationSec: durationSec,
            distanceMeters: distanceMeters,
            rpe: rpe,
            isWarmup: isWarmup,
            completedAt: completedAt,
            dateCreated: date
        )
    }

    /// Every measurement is optional, because which ones apply depends on the exercise: a plank
    /// records a duration and no reps, a run a distance and no weight.
    @Test("Test A Set Records Only What Applies")
    func testASetRecordsOnlyWhatApplies() {
        let lift = set(reps: 8, weightKg: 60)
        let plank = set(durationSec: 60)
        let run = set(durationSec: 1800, distanceMeters: 5000)

        #expect(lift.reps == 8 && lift.durationSec == nil && lift.distanceMeters == nil)
        #expect(plank.durationSec == 60 && plank.reps == nil && plank.weightKg == nil)
        #expect(run.distanceMeters == 5000 && run.durationSec == 1800)
    }

    @Test("Test A New Set Is Unfinished And Not A Warm-Up")
    func testANewSetIsUnfinishedAndNotAWarmUp() {
        let set = set(reps: 8, weightKg: 60)

        #expect(set.completedAt == nil)
        #expect(set.isWarmup == false)
        #expect(set.rpe == nil)
    }

    @Test("Test A Finished Set Records When")
    func testAFinishedSetRecordsWhen() {
        #expect(set(reps: 8, completedAt: date).completedAt == date)
    }

    @Test("Test A Set Round Trips")
    func testASetRoundTrips() throws {
        let original = set(reps: 8, weightKg: 60, rpe: 8.5, isWarmup: true, completedAt: date)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(WorkoutSetModel.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.reps == 8)
        #expect(decoded.weightKg == 60)
        #expect(decoded.rpe == 8.5)
        #expect(decoded.isWarmup)
        #expect(decoded.completedAt != nil)
    }

    /// A zero is a recorded zero and a nil is "not recorded" — the difference matters when
    /// totalling a workout, so encoding must not flatten one into the other.
    @Test("Test Zero And Unrecorded Stay Different Through Encoding")
    func testZeroAndUnrecordedStayDifferentThroughEncoding() throws {
        let zero = try JSONDecoder().decode(
            WorkoutSetModel.self,
            from: try JSONEncoder().encode(set(reps: 0, weightKg: 0))
        )
        let unrecorded = try JSONDecoder().decode(
            WorkoutSetModel.self,
            from: try JSONEncoder().encode(set())
        )

        #expect(zero.reps == 0)
        #expect(zero.weightKg == 0)
        #expect(unrecorded.reps == nil)
        #expect(unrecorded.weightKg == nil)
    }
}
