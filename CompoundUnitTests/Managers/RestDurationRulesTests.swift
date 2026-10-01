//
//  RestDurationRulesTests.swift
//  CompoundUnitTests
//
//  How long the rest after a set is. One case per row of the decision in
//  `RestDurationRules.restAfterCompleting`, on the exercise shape that reaches each row.
//

import Foundation
import Testing
@testable import Compound

struct RestDurationRulesTests {

    private static let start = Date(timeIntervalSince1970: 1_772_000_000)

    private func set(_ id: String, warmup: Bool = false, side: SetSide? = nil) -> WorkoutSetModel {
        WorkoutSetModel(id: id, authorId: "author-1", index: 1, reps: 8, side: side, isWarmup: warmup, dateCreated: Self.start)
    }

    private func exercise(_ sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "e1", authorId: "author-1", templateId: "t1", name: "Bench Press",
            trackingMode: .weightReps, index: 1, sets: sets
        )
    }

    /// Two warm-ups then two working sets, 100s base, every rule at a distinguishable scale.
    private let settings: WorkoutSettings = {
        var settings = WorkoutSettings(authorId: "author-1")
        settings.defaultRestDurationSeconds = 100
        settings.warmUpRestScaling = 0.5
        settings.sideSetRestScaling = 0.25
        settings.betweenExercisesRestScaling = 2.0
        settings.restAfterLastWarmUp = true
        settings.restBetweenSideSets = true
        settings.restBetweenExercises = true
        return settings
    }()

    private let noOverride = RestDurationRules.ExerciseContext(restOverrideSeconds: nil, exerciseTypeRawValue: nil)

    private func rest(
        after set: WorkoutSetModel,
        in exercise: WorkoutExerciseModel,
        settings: WorkoutSettings? = nil,
        context: RestDurationRules.ExerciseContext? = nil,
        custom: Int? = nil
    ) -> Int? {
        RestDurationRules.restAfterCompleting(
            set, in: exercise, settings: settings ?? self.settings, context: context ?? noOverride, customRestSeconds: custom
        )
    }

    @Test("Test A Custom Rest Wins Unscaled")
    func testACustomRestWinsUnscaled() {
        let warmup = set("w1", warmup: true)
        #expect(rest(after: warmup, in: exercise([warmup, set("x1")]), custom: 45) == 45)
    }

    /// Warm-ups are a ramp: nothing between them, whatever the scaling says.
    @Test("Test There Is Never A Rest Between Warm-Ups")
    func testThereIsNeverARestBetweenWarmUps() {
        let warmup = set("w1", warmup: true)
        #expect(rest(after: warmup, in: exercise([warmup, set("w2", warmup: true), set("x1")])) == nil)
    }

    /// The one warm-up rest is after the last one, before the first working set, scaled by the
    /// warm-up factor; off means none at all.
    @Test("Test The Last Warm-Up Rests Scaled And Only When Asked")
    func testTheLastWarmUpRestsScaledAndOnlyWhenAsked() {
        let last = set("w2", warmup: true)
        let exercise = exercise([set("w1", warmup: true), last, set("x1")])
        var off = settings
        off.restAfterLastWarmUp = false

        #expect(rest(after: last, in: exercise) == 50)
        #expect(rest(after: last, in: exercise, settings: off) == nil)
        #expect(WorkoutSettings(authorId: "author-1").restAfterLastWarmUp, "the last warm-up rests by default")
    }

    @Test("Test The Left Half Of A Pair Rests Like A Side Swap")
    func testTheLeftHalfOfAPairRestsLikeASideSwap() {
        let left = set("x1-l", side: .left)
        let exercise = exercise([left, set("x1-r", side: .right), set("x2-l", side: .left), set("x2-r", side: .right)])
        var off = settings
        off.restBetweenSideSets = false

        #expect(rest(after: left, in: exercise) == 25)
        #expect(rest(after: left, in: exercise, settings: off) == nil)
    }

    @Test("Test The Right Half Of A Pair Rests Between Sets")
    func testTheRightHalfOfAPairRestsBetweenSets() {
        let right = set("x1-r", side: .right)
        let exercise = exercise([set("x1-l", side: .left), right, set("x2-l", side: .left), set("x2-r", side: .right)])
        #expect(rest(after: right, in: exercise) == 100)
    }

    @Test("Test The Last Working Set Rests Toward The Next Exercise")
    func testTheLastWorkingSetRestsTowardTheNextExercise() {
        let last = set("x2")
        let exercise = exercise([set("x1"), last])
        var off = settings
        off.restBetweenExercises = false

        #expect(rest(after: last, in: exercise) == 200)
        #expect(rest(after: last, in: exercise, settings: off) == nil)
    }

    @Test("Test A Set In The Middle Rests The Base Duration")
    func testASetInTheMiddleRestsTheBaseDuration() {
        let first = set("x1")
        #expect(rest(after: first, in: exercise([first, set("x2")])) == 100)
    }

    @Test("Test Scaling To Nothing Means No Rest")
    func testScalingToNothingMeansNoRest() {
        let last = set("w2", warmup: true)
        var zeroed = settings
        zeroed.warmUpRestScaling = 0
        #expect(rest(after: last, in: exercise([set("w1", warmup: true), last, set("x1")]), settings: zeroed) == nil)
    }

    @Test("Test The Base Is The Narrowest Setting And A Zero Override Is None")
    func testTheBaseIsTheNarrowestSettingAndAZeroOverrideIsNone() {
        var settings = settings
        settings.restDurationsByExerciseType["strength"] = 70
        let first = set("x1")
        let exercise = exercise([first, set("x2")])

        let override = RestDurationRules.ExerciseContext(restOverrideSeconds: 30, exerciseTypeRawValue: "strength")
        let zeroOverride = RestDurationRules.ExerciseContext(restOverrideSeconds: 0, exerciseTypeRawValue: "strength")
        let typeOnly = RestDurationRules.ExerciseContext(restOverrideSeconds: nil, exerciseTypeRawValue: "strength")
        let unknownType = RestDurationRules.ExerciseContext(restOverrideSeconds: nil, exerciseTypeRawValue: "mobility")

        #expect(rest(after: first, in: exercise, settings: settings, context: override) == 30)
        #expect(rest(after: first, in: exercise, settings: settings, context: zeroOverride) == 70)
        #expect(rest(after: first, in: exercise, settings: settings, context: typeOnly) == 70)
        #expect(rest(after: first, in: exercise, settings: settings, context: unknownType) == 100)
    }
}
