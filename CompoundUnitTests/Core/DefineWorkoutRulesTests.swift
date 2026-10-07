//
//  DefineWorkoutRulesTests.swift
//  CompoundUnitTests
//
//  The workout editor's supersets: made, unmade, lettered and kept together on a reorder, and the
//  plan line under each exercise.
//

import Testing
import Foundation
@testable import Compound

@MainActor
struct DefineWorkoutRulesTests {

    private typealias Rules = DefineWorkoutRules

    /// Exercises named by id, with the group each is in.
    private func list(_ entries: [(String, String?)]) -> [WorkoutTemplateExercise] {
        entries.map { id, group in
            var exercise = WorkoutTemplateExercise(id: id, exercise: .mock, setRestTimers: false)
            exercise.supersetGroupId = group
            return exercise
        }
    }

    private func ids(_ exercises: [WorkoutTemplateExercise]) -> [String] { exercises.map(\.id) }
    private func groups(_ exercises: [WorkoutTemplateExercise]) -> [String?] { exercises.map(\.supersetGroupId) }

    // MARK: - Grouping

    @Test("Test Two Or More Chosen Share One Group Gathered Where The First Is")
    func testGrouping() {
        let exercises = list([("a", nil), ("b", nil), ("c", nil), ("d", nil)])

        let grouped = Rules.grouping(["b", "d"], in: exercises, groupId: "g")

        #expect(ids(grouped) == ["a", "b", "d", "c"])
        #expect(groups(grouped) == [nil, "g", "g", nil])
    }

    @Test("Test One Chosen Exercise Makes No Superset")
    func testGroupingNeedsTwo() {
        let exercises = list([("a", nil), ("b", nil)])

        #expect(Rules.grouping(["a"], in: exercises, groupId: "g") == exercises)
        #expect(Rules.grouping(["a", "missing"], in: exercises, groupId: "g") == exercises)
    }

    @Test("Test Joining A New Superset Dissolves An Old One Left With One")
    func testRegroupDissolvesOld() {
        let exercises = list([("a", "old"), ("b", "old"), ("c", nil)])

        let grouped = Rules.grouping(["b", "c"], in: exercises, groupId: "new")

        #expect(groups(grouped) == [nil, "new", "new"])
    }

    @Test("Test Removing A Member Of Three Keeps The Others Together")
    func testRemovingFromThree() {
        let exercises = list([("a", "g"), ("b", "g"), ("c", "g")])

        #expect(groups(Rules.removingFromSuperset("b", in: exercises)) == ["g", nil, "g"])
    }

    @Test("Test Removing A Member Of Two Dissolves The Superset")
    func testRemovingFromTwo() {
        let exercises = list([("a", "g"), ("b", "g"), ("c", nil)])

        #expect(groups(Rules.removingFromSuperset("a", in: exercises)) == [nil, nil, nil])
    }

    @Test("Test A Superset Of One From Elsewhere Is Dissolved")
    func testDissolvingLoneGroups() {
        let exercises = list([("a", "lone"), ("b", "g"), ("c", "g")])

        #expect(groups(Rules.dissolvingLoneGroups(exercises)) == [nil, "g", "g"])
    }

    // MARK: - Letters

    @Test("Test Supersets Are Lettered By First Appearance")
    func testLetters() {
        let exercises = list([("a", nil), ("b", "second"), ("c", "first"), ("d", "second"), ("e", "first"), ("f", "lone")])

        #expect(Rules.supersetLetters(exercises) == ["second": "A", "first": "B"])
    }

    // MARK: - Blocks

    @Test("Test A Superset Is One Block Where Its First Member Is")
    func testBlocks() {
        let exercises = list([("a", "g"), ("b", nil), ("c", "g")])

        #expect(Rules.blocks(exercises) == [["a", "c"], ["b"]])
    }

    // MARK: - Moving

    @Test("Test Moving A Member Down Moves The Whole Superset")
    func testMoveMemberDown() {
        let exercises = list([("a1", "a"), ("a2", "a"), ("x", nil), ("y", nil)])

        let moved = Rules.moving(exercises, from: [0], to: 3)

        #expect(ids(moved) == ["x", "a1", "a2", "y"])
    }

    @Test("Test Moving A Member Up Moves The Whole Superset")
    func testMoveMemberUp() {
        let exercises = list([("x", nil), ("a1", "a"), ("a2", "a")])

        let moved = Rules.moving(exercises, from: [2], to: 0)

        #expect(ids(moved) == ["a1", "a2", "x"])
    }

    @Test("Test A Member Changes Places Within Its Own Superset")
    func testMoveWithinGroup() {
        let exercises = list([("x", nil), ("a1", "a"), ("a2", "a"), ("y", nil)])

        #expect(ids(Rules.moving(exercises, from: [2], to: 1)) == ["x", "a2", "a1", "y"])
        #expect(ids(Rules.moving(exercises, from: [1], to: 3)) == ["x", "a2", "a1", "y"])
    }

    @Test("Test An Exercise Dropped Inside Another Superset Lands Beside It")
    func testDropInsideAnotherGroup() {
        let exercises = list([("a1", "a"), ("a2", "a"), ("x", nil)])
        let below = list([("x", nil), ("a1", "a"), ("a2", "a")])

        // Moving up into the middle goes before the superset; moving down goes after it.
        #expect(ids(Rules.moving(exercises, from: [2], to: 1)) == ["x", "a1", "a2"])
        #expect(ids(Rules.moving(below, from: [0], to: 2)) == ["a1", "a2", "x"])
    }

    @Test("Test Moving An Exercise On Its Own Is A Plain Move")
    func testPlainMove() {
        let exercises = list([("x", nil), ("y", nil), ("z", nil)])

        #expect(ids(Rules.moving(exercises, from: [0], to: 3)) == ["y", "z", "x"])
    }

    // MARK: - The plan line

    @Test("Test The Plan Line Names Only The Parts Set")
    func testPlanSummary() {
        var exercise = WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)
        #expect(Rules.planSummary(for: exercise) == nil)

        exercise.warmupSetCount = 3
        exercise.restSeconds = 120
        exercise.substituteExerciseIds = ["x", "y"]
        exercise.notes = "Pause at the bottom"
        exercise.setTargetsByMicrocycle = [MicrocycleSetTargets(fromMicrocycle: 2, setTargets: [])]
        #expect(Rules.planSummary(for: exercise) == "3 warm-ups · 2:00 rest · 2 alternatives · notes · varies by week")

        exercise = WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)
        exercise.warmupSetCount = 1
        exercise.substituteExerciseIds = ["x"]
        exercise.notes = "   "
        exercise.linkURL = "https://example.com"
        #expect(Rules.planSummary(for: exercise) == "1 warm-up · 1 alternative · link")
    }

    @Test("Test No Warm-ups Is A Plan Too")
    func testZeroWarmups() {
        var exercise = WorkoutTemplateExercise(exercise: .mock, setRestTimers: false)
        exercise.warmupSetCount = 0

        #expect(Rules.planSummary(for: exercise) == "0 warm-ups")
    }
}
