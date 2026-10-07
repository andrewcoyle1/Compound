//
//  ExerciseStripTests.swift
//  CompoundUnitTests
//
//  The exercise strip's items and the edge a new card comes in from. `ActiveWorkout+Strip`.
//

import Testing
import Foundation
@testable import Compound

struct ExerciseStripTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    /// `done` working sets first, then `open`, after any warm-ups.
    private func exercise(
        _ id: String,
        done: Int = 0,
        open: Int = 1,
        group: String? = nil,
        warmups: Int = 0,
        warmupsDone: Bool = false
    ) -> WorkoutExerciseModel {
        let warm = (0..<warmups).map { index in
            WorkoutSetModel(
                id: "\(id)-w\(index + 1)", authorId: "a", index: index + 1, reps: 5, weightKg: 40,
                isWarmup: true, completedAt: warmupsDone ? start : nil, dateCreated: start
            )
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

    // MARK: - Items

    @Test("Test Each Block Is One Item Counting Working Sets Only")
    func testItemsCountWorkingSets() {
        let exercises = [exercise("a", done: 2, open: 2, warmups: 2, warmupsDone: true), exercise("b", open: 3)]

        let items = ActiveWorkout.stripProgress(for: exercises, currentExerciseId: "a")

        #expect(items.map(\.id) == ["a", "b"])
        #expect(items[0].doneWorkingSets == 2)
        #expect(items[0].totalWorkingSets == 4)
        #expect(items[0].fraction == 0.5)
        #expect(items[0].isCurrent)
        #expect(!items[1].isCurrent)
        #expect(items[1].doneWorkingSets == 0)
    }

    @Test("Test A Superset Is One Item With Its Group Letter, Current From Any Member")
    func testSupersetIsOneItem() {
        let exercises = [
            exercise("a", group: "g"), exercise("b", done: 1, open: 1), exercise("c", done: 1, group: "g"),
            exercise("d", group: "h"), exercise("e", group: "h")
        ]

        let items = ActiveWorkout.stripProgress(for: exercises, currentExerciseId: "c")

        #expect(items.map(\.id) == ["a", "b", "d"])
        #expect(items[0].names == ["A", "C"])
        #expect(items[0].imageNames.count == 2)
        #expect(items[0].supersetLetter == "A")
        #expect(items[0].isCurrent)
        #expect(items[0].doneWorkingSets == 1)
        #expect(items[0].totalWorkingSets == 3)
        #expect(items[1].supersetLetter == nil)
        #expect(items[2].supersetLetter == "B")
    }

    @Test("Test An Item Is Complete Only When Every Working Set Is Logged")
    func testCompletion() {
        let items = ActiveWorkout.stripProgress(
            for: [exercise("a", done: 2, open: 0, warmups: 1), exercise("b", done: 1, open: 1), exercise("c", open: 0)],
            currentExerciseId: nil
        )

        // An open warm-up does not hold the item back; no working sets is not complete.
        #expect(items.map(\.isComplete) == [true, false, false])
        #expect(items.allSatisfy { !$0.isCurrent })
        #expect(items[2].fraction == 0)
    }

    @Test("Test No Exercises Is No Items")
    func testEmpty() {
        #expect(ActiveWorkout.stripProgress(for: [], currentExerciseId: "a").isEmpty)
    }

    // MARK: - Entry edge

    @Test("Test Moving Forward Comes In From The Trailing Edge, Back From The Leading")
    func testEntryEdgeFollowsOrder() {
        let order = [["a"], ["b", "d"], ["c"]]

        #expect(ActiveWorkout.entryEdge(from: "a", to: "c", order: order) == .trailing)
        #expect(ActiveWorkout.entryEdge(from: "c", to: "a", order: order) == .leading)
        // Into a superset by its second member, and back out of it by its first.
        #expect(ActiveWorkout.entryEdge(from: "a", to: "d", order: order) == .trailing)
        #expect(ActiveWorkout.entryEdge(from: "c", to: "b", order: order) == .leading)
    }

    @Test("Test Within A Block Or With An Unknown Exercise The Edge Is Trailing")
    func testEntryEdgeDefaults() {
        let order = [["a"], ["b", "d"], ["c"]]

        #expect(ActiveWorkout.entryEdge(from: "d", to: "b", order: order) == .trailing)
        #expect(ActiveWorkout.entryEdge(from: nil, to: "a", order: order) == .trailing)
        #expect(ActiveWorkout.entryEdge(from: "c", to: "new", order: order) == .trailing)
    }
}
