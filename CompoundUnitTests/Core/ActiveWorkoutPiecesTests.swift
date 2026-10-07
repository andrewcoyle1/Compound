//
//  ActiveWorkoutPiecesTests.swift
//  CompoundUnitTests
//
//  The set plan on the card: the piece the log button names after the set it logs
//  (`ActiveWorkout.nextPiece`), and the plan an exercise opens with (`ActiveWorkout.planSummary`).
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct ActiveWorkoutPiecesTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let settings = WorkoutSettings(authorId: "author-1")

    private func set(
        _ id: String,
        weight: Double? = 100,
        reps: Int? = 8,
        kind: SetKind = .standard,
        parent: String? = nil,
        side: SetSide? = nil,
        target: Int? = nil,
        warmup: Bool = false,
        logged: Bool = false
    ) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: 1, reps: reps, weightKg: weight, side: side, kind: kind,
            parentSetId: parent, targetReps: target, isWarmup: warmup, completedAt: logged ? start : nil, dateCreated: start
        )
    }

    private func exercise(_ sets: [WorkoutSetModel]) -> WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "e1", authorId: "author-1", templateId: "t1", name: "Bench Press", trackingMode: .weightReps,
            index: 1, sets: sets
        )
    }

    /// Set 3 of the mock-up: 100 × 8, then 80 and 64 to failure.
    private var dropSet: [WorkoutSetModel] {
        [
            set("s1", logged: true), set("s2", logged: true),
            set("s3", kind: .drop),
            set("d1", weight: 80, reps: nil, kind: .drop, parent: "s3"),
            set("d2", weight: 64, reps: nil, kind: .drop, parent: "s3"),
            set("s4", reps: 8, kind: .amrap, target: 8)
        ]
    }

    // MARK: - Next piece

    @Test("Test A Drop Follows With No Rest")
    func testADropFollowsWithNoRest() {
        let bench = exercise(dropSet)

        let hint = ActiveWorkout.nextPiece(after: "s3", in: bench, settings: settings, unit: .kilograms)
        #expect(hint?.text == "drop 1 · 80 kg, no rest")
        #expect(hint?.spokenText == "drop 1, 80 kilograms, no rest")
        #expect(ActiveWorkout.nextPiece(after: "d1", in: bench, settings: settings, unit: .kilograms)?.text == "drop 2 · 64 kg, no rest")
    }

    @Test("Test A Drop With Reps Shows Them")
    func testADropWithRepsShowsThem() {
        let bench = exercise([set("s1", kind: .drop), set("d1", weight: 80, reps: 8, kind: .drop, parent: "s1")])

        #expect(ActiveWorkout.nextPiece(after: "s1", in: bench, settings: settings, unit: .kilograms)?.text == "drop 1 · 80 kg × 8, no rest")
        #expect(ActiveWorkout.nextPiece(after: "s1", in: bench, settings: settings, unit: .pounds)?.text == "drop 1 · 176.4 lb × 8, no rest")
    }

    @Test("Test A Mini-Set Follows After Its Kind's Breath")
    func testAMiniSetFollowsAfterItsKindsBreath() {
        let sets = [set("s1", weight: 160, kind: .myo), set("m1", weight: 160, reps: 5, parent: "s1"), set("m2", weight: 160, reps: 5, parent: "s1")]
        var settings = settings
        settings.intraSetRestMyoSeconds = 15

        let hint = ActiveWorkout.nextPiece(after: "m1", in: exercise(sets), settings: settings, unit: .kilograms)
        #expect(hint?.text == "mini-set 2 · 160 kg × 5, 15 s breath")

        var restPause = sets
        restPause[0].kind = .restPause
        #expect(ActiveWorkout.nextPiece(after: "s1", in: exercise(restPause), settings: settings, unit: .kilograms)?.text == "mini-set 1 · 160 kg × 5, 20 s breath")
    }

    @Test("Test No Hint Before A Set Of Its Own")
    func testNoHintBeforeASetOfItsOwn() {
        let bench = exercise(dropSet)

        #expect(ActiveWorkout.nextPiece(after: "s2", in: bench, settings: settings, unit: .kilograms) == nil)
        // The set's last drop is followed by set 4.
        #expect(ActiveWorkout.nextPiece(after: "d2", in: bench, settings: settings, unit: .kilograms) == nil)
        #expect(ActiveWorkout.nextPiece(after: "s4", in: bench, settings: settings, unit: .kilograms) == nil)
        #expect(ActiveWorkout.nextPiece(after: "missing", in: bench, settings: settings, unit: .kilograms) == nil)
    }

    /// A drop already logged is not what comes next; the one after it is.
    @Test("Test A Logged Piece Is Passed Over")
    func testALoggedPieceIsPassedOver() {
        var sets = dropSet
        sets[3].completedAt = start

        #expect(ActiveWorkout.nextPiece(after: "s3", in: exercise(sets), settings: settings, unit: .kilograms)?.text == "drop 2 · 64 kg, no rest")
    }

    // MARK: - Plan summary

    @Test("Test The Plan Reads As The Mock-Up")
    func testThePlanReadsAsTheMockUp() {
        var sets = dropSet
        sets[0].completedAt = nil
        sets[1].completedAt = nil

        #expect(ActiveWorkout.planSummary(for: exercise(sets), unit: .kilograms)
            == "Set 3 is a drop set from your plan: 100 × 8, then 80 and 64 to failure, no rest between. Set 4 is AMRAP, target 8+.")
    }

    @Test("Test Drops With Reps And Mini-Sets")
    func testDropsWithRepsAndMiniSets() {
        let sets = [
            set("s1", kind: .drop), set("d1", weight: 80, reps: 10, kind: .drop, parent: "s1"),
            set("s2", kind: .myo), set("m1", reps: 5, parent: "s2"), set("m2", reps: 5, parent: "s2")
        ]

        #expect(ActiveWorkout.planSummary(for: exercise(sets), unit: .kilograms)
            == "Set 1 is a drop set from your plan: 100 × 8, then 80 × 10, no rest between. Set 2 is Myo-reps from your plan: 100 × 8, then 2 mini-sets, a short breath between.")
    }

    @Test("Test A Pair Is Told Once")
    func testAPairIsToldOnce() {
        let sets = [
            set("l1", side: .left, target: nil), set("r1", side: .right),
            set("l2", kind: .amrap, side: .left, target: 10), set("r2", kind: .amrap, side: .right, target: 10)
        ]

        #expect(ActiveWorkout.planSummary(for: exercise(sets), unit: .kilograms) == "Set 2 is AMRAP, target 10+.")
    }

    @Test("Test No Plan, Or One Already Begun, Says Nothing")
    func testNoPlanSaysNothing() {
        #expect(ActiveWorkout.planSummary(for: exercise([set("s1"), set("s2")]), unit: .kilograms) == nil)
        // An AMRAP set with no target from the plan is no plan.
        #expect(ActiveWorkout.planSummary(for: exercise([set("s1", kind: .amrap)]), unit: .kilograms) == nil)
        // Once a working set is logged the plan is under way.
        #expect(ActiveWorkout.planSummary(for: exercise(dropSet), unit: .kilograms) == nil)
        // A warm-up logged is not.
        let warmedUp = [set("w1", warmup: true, logged: true), set("s1", kind: .amrap, target: 8)]
        #expect(ActiveWorkout.planSummary(for: exercise(warmedUp), unit: .kilograms) == "Set 1 is AMRAP, target 8+.")
    }
}
