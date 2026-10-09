//
//  PropagationRuleTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// `ActiveWorkout.propagate(edit:original:in:)`: which sets a weight or reps edit is carried onto.
@MainActor
struct PropagationRuleTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(_ id: String, _ weightKg: Double?, reps: Int? = 8, side: SetSide? = nil, done: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id,
            authorId: "author-1",
            index: 1,
            reps: reps,
            weightKg: weightKg,
            side: side,
            isWarmup: false,
            completedAt: done ? start : nil,
            dateCreated: start
        )
    }

    /// Typing `weightKg` into `sets[index]`: the edit and the set list as the row binding leaves them.
    private func typing(_ weightKg: Double, into index: Int, of sets: [WorkoutSetModel]) -> (WorkoutSetModel, [WorkoutSetModel]) {
        var sets = sets
        sets[index].weightKg = weightKg
        return (sets[index], sets)
    }

    @Test("Test An Edit Carries To Open Siblings Holding The Original")
    func testAnEditCarriesToOpenSiblingsHoldingTheOriginal() {
        let before = [set("s1", 100), set("s2", 100), set("s3", 100)]
        let (edit, sets) = typing(105, into: 0, of: before)

        let result = ActiveWorkout.propagate(edit: edit, original: before[0], in: sets)

        #expect(result.map(\.weightKg) == [105, 105, 105])
    }

    /// The edge-case report's #5: the back-off set stays at 80.
    @Test("Test Typing 82.5 Leaves The 80 Back-Off Set Alone")
    func testTyping82Point5LeavesThe80BackOffSetAlone() {
        let before = [set("s1", 100), set("s2", 100), set("s3", 80)]
        let (edit, sets) = typing(82.5, into: 0, of: before)

        let result = ActiveWorkout.propagate(edit: edit, original: before[0], in: sets)

        #expect(result.map(\.weightKg) == [82.5, 82.5, 80])
    }

    /// The rule matches whatever it is told was the original, which is why the caller must pass
    /// the value from before the first keystroke: an intermediate 80 would catch the back-off set.
    @Test("Test The Match Is On The Original Passed In, Not An Intermediate Value")
    func testTheMatchIsOnTheOriginalNotAnIntermediateValue() {
        let before = [set("s1", 100), set("s2", 100), set("s3", 80)]
        var intermediate = before
        intermediate[0].weightKg = 80
        let (edit, sets) = typing(82.5, into: 0, of: before)

        #expect(ActiveWorkout.propagate(edit: edit, original: before[0], in: sets).map(\.weightKg) == [82.5, 82.5, 80])
        #expect(ActiveWorkout.propagate(edit: edit, original: intermediate[0], in: sets).map(\.weightKg) == [82.5, 100, 82.5])
    }

    @Test("Test An Edit Stays On Its Own Side")
    func testAnEditStaysOnItsOwnSide() {
        let before = [
            set("l1", 20, side: .left), set("r1", 20, side: .right),
            set("l2", 20, side: .left), set("r2", 20, side: .right)
        ]
        let (edit, sets) = typing(22.5, into: 0, of: before)

        let result = ActiveWorkout.propagate(edit: edit, original: before[0], in: sets)

        #expect(result.map(\.weightKg) == [22.5, 20, 22.5, 20])
    }

    @Test("Test Logged Siblings Are Never Changed")
    func testLoggedSiblingsAreNeverChanged() {
        let before = [set("s1", 100, done: true), set("s2", 100), set("s3", 100, done: true), set("s4", 100)]
        let (edit, sets) = typing(110, into: 1, of: before)

        let result = ActiveWorkout.propagate(edit: edit, original: before[1], in: sets)

        #expect(result.map(\.weightKg) == [100, 110, 100, 110])
    }

    @Test("Test Correcting A Logged Set Carries Nowhere")
    func testCorrectingALoggedSetCarriesNowhere() {
        let before = [set("s1", 100, done: true), set("s2", 100)]
        let (edit, sets) = typing(110, into: 0, of: before)

        #expect(ActiveWorkout.propagate(edit: edit, original: before[0], in: sets) == sets)
    }

    /// Reps are matched together with the weight: a sibling with the same weight but other reps
    /// was set up differently on purpose.
    @Test("Test A Reps Edit Carries Only Where Weight And Reps Both Match")
    func testARepsEditCarriesOnlyWhereWeightAndRepsBothMatch() {
        let before = [set("s1", 100, reps: 8), set("s2", 100, reps: 8), set("s3", 100, reps: 12)]
        var sets = before
        sets[0].reps = 6

        let result = ActiveWorkout.propagate(edit: sets[0], original: before[0], in: sets)

        #expect(result.map(\.reps) == [6, 6, 12])
        #expect(result.map(\.weightKg) == [100, 100, 100])
    }

    @Test("Test No Change Leaves The Sets As They Are")
    func testNoChangeLeavesTheSetsAsTheyAre() {
        let before = [set("s1", 100), set("s2", 100)]

        #expect(ActiveWorkout.propagate(edit: before[0], original: before[0], in: before) == before)
    }
}
