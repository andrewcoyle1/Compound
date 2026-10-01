//
//  RestOverMessageTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)

/// What the rest-over alert says: the set that comes next, in the exercise's unit, or nothing
/// beyond the title when no set is left. Built from the content state, so no activity is needed.
@MainActor
struct RestOverMessageTests {

    private let start = Date(timeIntervalSince1970: 1_772_000_000)

    private func session(completed: [Bool], weightKg: Double? = 60, reps: Int? = 8) -> WorkoutSessionModel {
        let sets = completed.enumerated().map { index, done in
            WorkoutSetModel(
                id: "s\(index)", authorId: "author-1", index: index + 1, reps: reps, weightKg: weightKg,
                isWarmup: false, completedAt: done ? start : nil, dateCreated: start
            )
        }
        let exercise = WorkoutExerciseModel(
            id: "e1", authorId: "author-1", templateId: "t1", name: "Bench Press",
            trackingMode: .weightReps, index: 1, sets: sets
        )
        return WorkoutSessionModel(id: "session-1", authorId: "author-1", name: "Upper", dateCreated: start, exercises: [exercise])
    }

    private func manager(unit: LiveActivityWeightUnit = .kilograms) -> LiveActivityManager {
        LiveActivityManager(logger: LogManager(), activityLookup: { _ in nil }, weightUnit: { _ in unit })
    }

    @Test("Test The Rest-Over Text Names The Next Set")
    func testTheRestOverTextNamesTheNextSet() {
        let text = manager().restOverMessage(session: session(completed: [true, false]), currentExerciseIndex: 0)
        let expected = "Next: Bench Press, \(Format.weight(kg: 60, unit: ExerciseWeightUnit.kilograms)) × 8"
        #expect(text == expected)
    }

    @Test("Test The Rest-Over Text Uses The Exercise's Unit")
    func testTheRestOverTextUsesTheExercisesUnit() {
        let text = manager(unit: .pounds).restOverMessage(session: session(completed: [false]), currentExerciseIndex: 0)
        #expect(text?.contains(Format.weight(kg: 60, unit: ExerciseWeightUnit.pounds)) == true)
    }

    private func runSession(meters: Double) -> WorkoutSessionModel {
        let set = WorkoutSetModel(
            id: "r1", authorId: "author-1", index: 1, distanceMeters: meters,
            isWarmup: false, completedAt: nil, dateCreated: start
        )
        let exercise = WorkoutExerciseModel(
            id: "e1", authorId: "author-1", templateId: "t1", name: "Row",
            trackingMode: .distanceTime, index: 1, sets: [set]
        )
        return WorkoutSessionModel(id: "session-1", authorId: "author-1", name: "Cardio", dateCreated: start, exercises: [exercise])
    }

    /// The rest-over text used to show metres to everyone. It now follows the exercise's own
    /// distance unit, as the tracker does.
    @Test("Test The Rest-Over Distance Uses The Exercise's Distance Unit", arguments: [LiveActivityDistanceUnit.meters, .miles])
    func testTheRestOverDistanceUsesTheExercisesDistanceUnit(unit: LiveActivityDistanceUnit) {
        let manager = LiveActivityManager(logger: LogManager(), activityLookup: { _ in nil }, distanceUnit: { _ in unit })
        let text = manager.restOverMessage(session: runSession(meters: 1609.344), currentExerciseIndex: 0)
        let exerciseUnit: ExerciseDistanceUnit = unit == .miles ? .miles : .meters
        #expect(text == "Next: Row, \(Format.distance(meters: 1609.344, exerciseUnit: exerciseUnit))")
    }

    /// A state encoded before the distance unit existed (an activity started by the previous
    /// version) still decodes, and reads as metres.
    @Test("Test A Content State Without A Distance Unit Still Decodes")
    func testAContentStateWithoutADistanceUnitStillDecodes() throws {
        let state = WorkoutActivityAttributes.ContentState(
            isActive: true, completedSetsCount: 0, totalSetsCount: 1, currentExerciseName: "Row",
            currentExerciseIndex: 0, totalExercisesCount: 1, currentExerciseCompletedSetsCount: 0,
            currentExerciseTotalSetsCount: 1, targetDistanceMeters: 400, progress: 0, isWorkoutEnded: false,
            isProcessingIntent: false, isAllSetsComplete: false, distanceUnit: .miles
        )
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "distanceUnit")
        let old = try JSONDecoder().decode(WorkoutActivityAttributes.ContentState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.distanceUnit == nil)
        #expect(old.restOverMessage == "Next: Row, \(Format.distance(meters: 400, exerciseUnit: .meters))")
    }

    @Test("Test A Set With No Figures Yet Is Named Without Them")
    func testASetWithNoFiguresYetIsNamedWithoutThem() {
        let text = manager().restOverMessage(session: session(completed: [false], weightKg: nil, reps: nil), currentExerciseIndex: 0)
        #expect(text == "Next: Bench Press")
    }

    /// Nothing left: the alert falls back to its title alone.
    @Test("Test With Every Set Logged There Is Nothing Next")
    func testWithEverySetLoggedThereIsNothingNext() {
        #expect(manager().restOverMessage(session: session(completed: [true, true]), currentExerciseIndex: 0) == nil)
    }
}

#endif
