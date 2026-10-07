//
//  ActiveWorkoutLogRuleTests.swift
//  CompoundUnitTests
//
//  The one log rule the tracker and the Live Activity share. `ActiveWorkout+Log`.
//

import Testing
import Foundation
@testable import Compound

struct ActiveWorkoutLogRuleTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let now = Date(timeIntervalSince1970: 1_000_500)
    private let context = RestDurationRules.ExerciseContext(restOverrideSeconds: nil, exerciseTypeRawValue: nil)

    private var settings: WorkoutSettings {
        var settings = WorkoutSettings(authorId: "a")
        settings.defaultRestDurationSeconds = 90
        return settings
    }

    /// `done` sets first, then `open`; ids are "<exercise>-<n>".
    private func exercise(_ id: String, done: Int = 0, open: Int = 2, reps: Int? = 8, group: String? = nil) -> WorkoutExerciseModel {
        let sets = (0..<(done + open)).map { index in
            WorkoutSetModel(
                id: "\(id)-\(index + 1)", authorId: "a", index: index + 1, reps: reps, weightKg: 80,
                isWarmup: false, completedAt: index < done ? start : nil, dateCreated: start
            )
        }
        return WorkoutExerciseModel(
            id: id, authorId: "a", templateId: "t-\(id)", name: id.uppercased(), trackingMode: .weightReps,
            index: 1, sets: sets, supersetGroupId: group
        )
    }

    private func session(_ exercises: [WorkoutExerciseModel]) -> WorkoutSessionModel {
        WorkoutSessionModel(id: "s", authorId: "a", name: "W", dateCreated: start, exercises: exercises)
    }

    private func log(_ setId: String, in session: WorkoutSessionModel, custom: Int? = nil) -> ActiveWorkout.LogOutcome? {
        ActiveWorkout.log(setId: setId, in: session, settings: settings, context: context, customRestSeconds: custom, now: now)
    }

    @Test("Test An Invalid Set Is Refused And The Session Left Unchanged")
    func testInvalidSetRefused() throws {
        let before = session([exercise("a", reps: nil)])

        let outcome = try #require(log("a-1", in: before))

        #expect(outcome.problem != nil)
        #expect(outcome.session == before)
        #expect(outcome.restSeconds == nil)
        #expect(outcome.focusExerciseId == nil)
    }

    @Test("Test Logging Stamps The Set At Now")
    func testStamps() throws {
        let outcome = try #require(log("a-1", in: session([exercise("a")])))

        #expect(outcome.problem == nil)
        let sets = outcome.session.exercises[0].sets
        #expect(sets[0].completedAt == now)
        #expect(sets[1].completedAt == nil)
        #expect(outcome.restSeconds == 90)
    }

    @Test("Test An Unknown Or Logged Set Has Nothing To Log")
    func testNothingToLog() {
        let workout = session([exercise("a", done: 1, open: 1)])

        #expect(log("a-1", in: workout) == nil)
        #expect(log("missing", in: workout) == nil)
    }

    @Test("Test No Rest After The Workout's Final Set")
    func testNoRestAfterFinalSet() throws {
        let outcome = try #require(log("b-2", in: session([exercise("a", done: 2, open: 0), exercise("b", done: 1, open: 1)]), custom: 120))

        #expect(outcome.problem == nil)
        #expect(outcome.restSeconds == nil)
    }

    @Test("Test Superset A1 Moves Focus To B")
    func testSupersetMovesToPartner() throws {
        let outcome = try #require(log("a-1", in: session([exercise("a", group: "g"), exercise("b", group: "g")])))

        #expect(outcome.focusExerciseId == "b")
        // A walk to the partner: no rest by default.
        #expect(outcome.restSeconds == nil)
    }

    @Test("Test A Rest Set By Hand On The Row Wins")
    func testCustomRestWins() throws {
        let outcome = try #require(log("a-1", in: session([exercise("a")]), custom: 45))

        #expect(outcome.restSeconds == 45)
    }
}
