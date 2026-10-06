//
//  ActiveWorkoutFocusTests.swift
//  CompoundUnitTests
//
//  Where the card goes: blocks, the rounds of a superset, after a set is logged and when a rest
//  ends. `ActiveWorkout+Focus`.
//

import Testing
import Foundation
@testable import Compound

struct ActiveWorkoutFocusTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    /// `done` sets first, then `open`; ids are "<exercise>-<n>".
    private func exercise(
        _ id: String,
        done: Int = 0,
        open: Int = 1,
        group: String? = nil,
        warmups: Int = 0
    ) -> WorkoutExerciseModel {
        let warm = (0..<warmups).map { index in
            WorkoutSetModel(id: "\(id)-w\(index + 1)", authorId: "a", index: index + 1, reps: 5, weightKg: 40, isWarmup: true, dateCreated: start)
        }
        let working = (0..<(done + open)).map { index in
            WorkoutSetModel(
                id: "\(id)-\(index + 1)", authorId: "a", index: warmups + index + 1, reps: 8, weightKg: 80,
                isWarmup: false, completedAt: index < done ? start : nil, dateCreated: start
            )
        }
        return WorkoutExerciseModel(
            id: id, authorId: "a", templateId: "t-\(id)", name: id.uppercased(), trackingMode: .weightReps,
            index: 1, sets: warm + working, supersetGroupId: group
        )
    }

    private let settings = WorkoutSettings(authorId: "a")

    // MARK: - Blocks

    @Test("Test A Superset Is One Block Where Its First Member Is")
    func testBlocks() {
        let exercises = [exercise("a"), exercise("b", group: "g"), exercise("c"), exercise("d", group: "g"), exercise("e", group: "h")]

        #expect(ActiveWorkout.blocks(exercises) == [["a"], ["b", "d"], ["c"], ["e"]])
        #expect(ActiveWorkout.blocks([]) == [])
    }

    // MARK: - Log button

    /// The button walks the rounds: A1, B1, A2, B2. On A with B1 still open, it opens B rather
    /// than logging a set the card does not show.
    @Test("Test The Log Button Walks A Superset In Rounds")
    func testPrimaryActionWalksRounds() {
        let fresh = [exercise("a", open: 2, group: "g"), exercise("b", open: 2, group: "g")]
        #expect(ActiveWorkout.primaryAction(exercises: fresh, currentExerciseId: "a") == .logSet(exerciseId: "a", setId: "a-1"))

        let afterA1 = [exercise("a", done: 1, open: 1, group: "g"), exercise("b", open: 2, group: "g")]
        #expect(ActiveWorkout.primaryAction(exercises: afterA1, currentExerciseId: "b") == .logSet(exerciseId: "b", setId: "b-1"))
        #expect(ActiveWorkout.primaryAction(exercises: afterA1, currentExerciseId: "a") == .next(exerciseId: "b"))

        let afterB1 = [exercise("a", done: 1, open: 1, group: "g"), exercise("b", done: 1, open: 1, group: "g")]
        #expect(ActiveWorkout.primaryAction(exercises: afterB1, currentExerciseId: "a") == .logSet(exerciseId: "a", setId: "a-2"))
    }

    /// A member with nothing left is skipped, and the others carry on.
    @Test("Test The Log Button Skips A Finished Member")
    func testPrimaryActionSkipsFinishedMember() {
        let exercises = [exercise("a", done: 2, open: 0, group: "g"), exercise("b", done: 2, open: 1, group: "g")]

        #expect(ActiveWorkout.primaryAction(exercises: exercises, currentExerciseId: "a") == .next(exerciseId: "b"))
        #expect(ActiveWorkout.primaryAction(exercises: exercises, currentExerciseId: "b") == .logSet(exerciseId: "b", setId: "b-3"))
    }

    /// Next skips a block already finished and wraps round to one put off earlier.
    @Test("Test Next Wraps And Skips Finished Blocks")
    func testNextWrapsAndSkips() {
        let exercises = [exercise("a"), exercise("b", done: 1, open: 0), exercise("c", done: 1, open: 0)]

        #expect(ActiveWorkout.primaryAction(exercises: exercises, currentExerciseId: "b") == .next(exerciseId: "a"))
    }

    // MARK: - After logging

    /// A1 logged: on to B for B1, whatever rest follows.
    @Test("Test Inside A Superset The Card Goes To The Partner")
    func testFocusMovesToPartner() {
        let exercises = [exercise("a", done: 1, open: 1, group: "g"), exercise("b", open: 2, group: "g")]

        #expect(ActiveWorkout.focus(afterLogging: "a-1", in: exercises, settings: settings, restFollows: true) == "b")
        #expect(ActiveWorkout.focus(afterLogging: "a-1", in: exercises, settings: settings, restFollows: false) == "b")
    }

    /// B1 logged closes the round: back to A for A2.
    @Test("Test The Round's Last Set Hands Back To The First Member")
    func testFocusWrapsToFirstMember() {
        let exercises = [exercise("a", done: 1, open: 1, group: "g"), exercise("b", done: 1, open: 1, group: "g")]

        #expect(ActiveWorkout.focus(afterLogging: "b-1", in: exercises, settings: settings, restFollows: true) == "a")
    }

    @Test("Test Superset Auto-Scroll Off Keeps The Card")
    func testFocusAutoScrollOff() {
        var settings = settings
        settings.supersetAutoScroll = false
        let exercises = [exercise("a", done: 1, open: 1, group: "g"), exercise("b", open: 2, group: "g")]

        #expect(ActiveWorkout.focus(afterLogging: "a-1", in: exercises, settings: settings, restFollows: false) == nil)
    }

    /// A circuit of three goes A, B, C, skipping a member with nothing left.
    @Test("Test A Circuit Skips A Finished Member")
    func testFocusCircuit() {
        let exercises = [
            exercise("a", done: 1, open: 1, group: "g"),
            exercise("b", done: 1, open: 0, group: "g"),
            exercise("c", open: 2, group: "g")
        ]

        #expect(ActiveWorkout.focus(afterLogging: "a-1", in: exercises, settings: settings, restFollows: false) == "c")
    }

    @Test("Test A Set With More Left In The Exercise Keeps The Card")
    func testFocusStaysMidExercise() {
        let exercises = [exercise("a", done: 1, open: 1), exercise("b")]

        #expect(ActiveWorkout.focus(afterLogging: "a-1", in: exercises, settings: settings, restFollows: false) == nil)
    }

    /// T3: the card stays on a finished exercise while its rest runs.
    @Test("Test A Finished Exercise Stays During Its Rest")
    func testFocusStaysDuringRest() {
        let exercises = [exercise("a", done: 1, open: 0), exercise("b")]

        #expect(ActiveWorkout.focus(afterLogging: "a-1", in: exercises, settings: settings, restFollows: true) == nil)
    }

    /// With no rest to wait out, on to the next block with sets left, skipping a finished one.
    @Test("Test A Finished Exercise With No Rest Moves On")
    func testFocusMovesWithoutRest() {
        var autoNextOff = settings
        autoNextOff.exerciseAutoNext = false
        let exercises = [exercise("a", done: 1, open: 0), exercise("b", done: 1, open: 0), exercise("c", group: "g"), exercise("d", group: "g")]

        #expect(ActiveWorkout.focus(afterLogging: "a-1", in: exercises, settings: settings, restFollows: false) == "c")
        #expect(ActiveWorkout.focus(afterLogging: "a-1", in: exercises, settings: autoNextOff, restFollows: false) == nil)
    }

    @Test("Test A Finished Superset Stays During Its Rest")
    func testFocusFinishedSupersetStays() {
        let exercises = [exercise("a", done: 1, open: 0, group: "g"), exercise("b", done: 1, open: 0, group: "g"), exercise("c")]

        #expect(ActiveWorkout.focus(afterLogging: "b-1", in: exercises, settings: settings, restFollows: true) == nil)
        #expect(ActiveWorkout.focus(afterLogging: "b-1", in: exercises, settings: settings, restFollows: false) == "c")
    }

    // MARK: - When the rest ends

    @Test("Test When The Rest Ends A Finished Exercise Moves On")
    func testFocusWhenRestEnds() {
        var autoNextOff = settings
        autoNextOff.exerciseAutoNext = false
        let exercises = [exercise("a", done: 1, open: 0), exercise("b", done: 1, open: 0), exercise("c")]

        #expect(ActiveWorkout.focusWhenRestEnds(current: "a", exercises: exercises, settings: settings) == "c")
        #expect(ActiveWorkout.focusWhenRestEnds(current: "a", exercises: exercises, settings: autoNextOff) == nil)
        #expect(ActiveWorkout.focusWhenRestEnds(current: "c", exercises: exercises, settings: settings) == nil)
    }

    @Test("Test When The Rest Ends After The Last Set Nothing Moves")
    func testFocusWhenRestEndsAllDone() {
        let exercises = [exercise("a", done: 1, open: 0), exercise("b", done: 1, open: 0)]

        #expect(ActiveWorkout.focusWhenRestEnds(current: "b", exercises: exercises, settings: settings) == nil)
    }

    // MARK: - Header

    /// A superset counts once, and the header says it is one.
    @Test("Test The Header Counts A Superset Once")
    func testProgressCountsBlocks() {
        let exercises = [exercise("a"), exercise("b", group: "g"), exercise("c", group: "g"), exercise("d")]

        let onSuperset = ActiveWorkout.progress(of: exercises, currentIndex: 2)
        #expect(onSuperset.exerciseNumber == 2)
        #expect(onSuperset.exerciseCount == 3)
        #expect(onSuperset.isSuperset)

        let onSingle = ActiveWorkout.progress(of: exercises, currentIndex: 3)
        #expect(onSingle.exerciseNumber == 3)
        #expect(!onSingle.isSuperset)
    }

    /// Warm-ups come before the first round, and a round's set number counts a pair once.
    @Test("Test Warm-Ups Come Before The First Round")
    func testWarmupsBeforeRounds() {
        let exercises = [exercise("a", open: 2, group: "g", warmups: 1), exercise("b", open: 2, group: "g")]

        #expect(ActiveWorkout.primaryAction(exercises: exercises, currentExerciseId: "b") == .next(exerciseId: "a"))
        #expect(ActiveWorkout.primaryAction(exercises: exercises, currentExerciseId: "a") == .logSet(exerciseId: "a", setId: "a-w1"))
    }
}
