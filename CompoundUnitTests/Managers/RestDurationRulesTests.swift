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

    private func set(_ id: String, warmup: Bool = false, side: SetSide? = nil, kind: SetKind = .standard, parent: String? = nil) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: 1, reps: 8, side: side, kind: kind, parentSetId: parent,
            isWarmup: warmup, dateCreated: Self.start
        )
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

    // MARK: - Sub-sets

    /// A drop follows its parent at once; the drop then rests as its parent would have.
    @Test("Test There Is No Rest Before A Drop")
    func testThereIsNoRestBeforeADrop() {
        let parent = set("x1")
        let drop = set("x1-d", kind: .drop, parent: "x1")
        let exercise = exercise([parent, drop, set("x2")])

        #expect(rest(after: parent, in: exercise) == nil)
        #expect(rest(after: drop, in: exercise) == 100)
    }

    /// Mini-sets and clusters take the intra-set rest, 15 seconds unless chosen, none at zero.
    @Test("Test Myo, Rest-Pause And Cluster Rows Rest The Intra-Set Rest", arguments: [SetKind.myo, .restPause, .cluster])
    func testIntraSetRest(kind: SetKind) {
        let parent = set("x1", kind: kind)
        let first = set("x1-m1", kind: kind, parent: "x1")
        let last = set("x1-m2", kind: kind, parent: "x1")
        let exercise = exercise([parent, first, last, set("x2")])
        var chosen = settings
        chosen.intraSetRestSeconds = 20
        var none = settings
        none.intraSetRestSeconds = 0

        #expect(rest(after: parent, in: exercise) == 15)
        #expect(rest(after: first, in: exercise) == 15)
        #expect(rest(after: last, in: exercise) == 100)
        #expect(rest(after: parent, in: exercise, settings: chosen) == 20)
        #expect(rest(after: parent, in: exercise, settings: none) == nil)
    }

    /// A plain row under a myo parent is still a mini-set of it.
    @Test("Test A Plain Sub-Set Takes Its Parent's Kind")
    func testAPlainSubSetTakesItsParentsKind() {
        let parent = set("x1", kind: .myo)
        #expect(rest(after: parent, in: exercise([parent, set("x1-m", parent: "x1"), set("x2")])) == 15)
    }

    /// The parent of the last set is still the last set: its trailing drop walks to the next
    /// exercise, rather than the parent being taken for a set in the middle.
    @Test("Test A Sub-Set Does Not End Its Parent's Rest Rule")
    func testASubSetDoesNotEndItsParentsRestRule() {
        let last = set("x2")
        let drop = set("x2-d", kind: .drop, parent: "x2")
        let exercise = exercise([set("x1"), last, drop])

        #expect(rest(after: last, in: exercise) == nil)
        #expect(rest(after: drop, in: exercise) == 200)
    }

    /// In a superset, a drop still to come keeps the parent's rule: no walk to the partner first.
    @Test("Test A Drop In A Superset Comes Before The Partner")
    func testADropInASupersetComesBeforeThePartner() {
        var first = member("a", sets: 2)
        first.sets.insert(set("a1-d", kind: .drop, parent: "a1"), at: 1)
        var transition = settings
        transition.supersetTransitionRestSeconds = 30
        let workout = [first, member("b", sets: 2)]

        #expect(rest(after: "a1", in: workout, settings: transition) == nil)
        #expect(rest(after: "a1-d", in: workout, settings: transition) == 30)
    }

    // MARK: - Across the workout

    /// `count` open working sets of exercise `id`, in superset `group`; the first `done` logged.
    private func member(_ id: String, sets count: Int, done: Int = 0, group: String? = "g") -> WorkoutExerciseModel {
        let sets = (0..<count).map { index in
            WorkoutSetModel(
                id: "\(id)\(index + 1)", authorId: "author-1", index: index + 1, reps: 8,
                isWarmup: false, completedAt: index < done ? Self.start : nil, dateCreated: Self.start
            )
        }
        return WorkoutExerciseModel(
            id: id, authorId: "author-1", templateId: "t-\(id)", name: id, trackingMode: .weightReps,
            index: 1, sets: sets, supersetGroupId: group
        )
    }

    private func rest(after setId: String, in workout: [WorkoutExerciseModel], settings: WorkoutSettings? = nil, custom: Int? = nil) -> Int? {
        let exercise = workout.first { $0.sets.contains { $0.id == setId } }!
        let set = exercise.sets.first { $0.id == setId }!
        return RestDurationRules.restAfterCompleting(
            set, in: exercise, workout: workout, settings: settings ?? self.settings, context: noOverride, customRestSeconds: custom
        )
    }

    /// Finish comes next: no rest stands in front of it, not even one set by hand.
    @Test("Test The Workout's Final Set Rests Not At All")
    func testTheFinalSetRestsNotAtAll() {
        let workout = [member("a", sets: 2, done: 1, group: nil), member("b", sets: 1, done: 1, group: nil)]

        #expect(rest(after: "a2", in: workout) == nil)
        #expect(rest(after: "a2", in: workout, custom: 60) == nil)
        // Not final while another exercise has a set open.
        #expect(rest(after: "a2", in: [workout[0], member("b", sets: 1, group: nil)]) == 200)
    }

    /// A1 to B1 is a walk to the partner: none by default, the transition when one is set.
    @Test("Test A Superset Partner Set Gets The Transition Rest")
    func testASupersetPartnerSetGetsTheTransitionRest() {
        let workout = [member("a", sets: 2), member("b", sets: 2)]
        var transition = settings
        transition.supersetTransitionRestSeconds = 15

        #expect(rest(after: "a1", in: workout) == nil)
        #expect(rest(after: "a1", in: workout, settings: transition) == 15)
    }

    /// B1 closes the round: the base rest, not the between-exercises one.
    @Test("Test The Round's Last Set Rests The Base")
    func testTheRoundsLastSetRestsTheBase() {
        let workout = [member("a", sets: 2, done: 1), member("b", sets: 2)]

        #expect(rest(after: "b1", in: workout) == 100)
    }

    /// The last round's last set is the walk to the next exercise. A's last set before B's is
    /// still mid-round, not between exercises.
    @Test("Test The Last Round Rests Between Exercises")
    func testTheLastRoundRestsBetweenExercises() {
        let workout = [member("a", sets: 2, done: 1), member("b", sets: 2, done: 1), member("c", sets: 1, group: nil)]

        #expect(rest(after: "a2", in: workout) == nil)
        #expect(rest(after: "b2", in: [member("a", sets: 2, done: 2), workout[1], workout[2]]) == 200)
    }

    /// A circuit of three: two walks, then the round's rest.
    @Test("Test A Circuit Of Three Rests After The Round")
    func testACircuitOfThreeRestsAfterTheRound() {
        let workout = [member("a", sets: 2), member("b", sets: 2), member("c", sets: 2)]

        #expect(rest(after: "a1", in: workout) == nil)
        #expect(rest(after: "b1", in: [member("a", sets: 2, done: 1), workout[1], workout[2]]) == nil)
        #expect(rest(after: "c1", in: [member("a", sets: 2, done: 1), member("b", sets: 2, done: 1), workout[2]]) == 100)
    }
}
