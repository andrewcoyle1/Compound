//
//  RestOverMessageTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

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
