//
//  WorkoutResumeRuleTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The resume rule's two pure halves: which sets the receipt owns up to, and what the rest's owner
/// does with a rest it finds after a cold launch.
@MainActor
struct WorkoutResumeRuleTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(_ id: String, index: Int = 1, weightKg: Double? = 100, isWarmup: Bool = false, doneAt offset: TimeInterval?) -> WorkoutSetModel {
        WorkoutSetModel(
            id: id, authorId: "author-1", index: index, reps: 8, weightKg: weightKg,
            isWarmup: isWarmup, completedAt: offset.map { start.addingTimeInterval($0) }, dateCreated: start
        )
    }

    private var bench: WorkoutExerciseModel {
        WorkoutExerciseModel(
            id: "e1", authorId: "author-1", templateId: "template-e1", name: "Bench Press",
            trackingMode: .weightReps, index: 1,
            sets: [
                set("w1", isWarmup: true, doneAt: 10),
                set("s1", index: 2, doneAt: 100),
                set("s2", index: 3, doneAt: 300),
                set("s3", index: 4, doneAt: nil)
            ]
        )
    }

    // MARK: - Receipt

    @Test("Test The Receipt Holds The Sets Logged Since The Screen Last Looked, Oldest First")
    func testReceiptHoldsSetsLoggedSince() {
        let squat = WorkoutExerciseModel(
            id: "e2", authorId: "author-1", templateId: "template-e2", name: "Squat",
            trackingMode: .weightReps, index: 2, sets: [set("q1", doneAt: 200)]
        )

        let receipt = ActiveWorkout.receipt(in: [bench, squat], loggedAfter: start.addingTimeInterval(150))

        #expect(receipt.map(\.id) == ["q1", "s2"])
    }

    @Test("Test A Screen That Never Looked Owes No Receipt")
    func testNeverLookedOwesNothing() {
        #expect(ActiveWorkout.receipt(in: [bench], loggedAfter: nil).isEmpty)
    }

    @Test("Test Nothing Logged Since Means No Receipt")
    func testNothingSince() {
        #expect(ActiveWorkout.receipt(in: [bench], loggedAfter: start.addingTimeInterval(300)).isEmpty)
    }

    @Test("Test A Receipt Line Reads Set Number And Figures")
    func testReceiptLine() throws {
        let exercise = bench
        let line = ActiveWorkout.receiptLine(for: exercise.sets[2], in: exercise, unit: .kilograms, distanceUnit: .meters)
        let warmUp = ActiveWorkout.receiptLine(for: exercise.sets[0], in: exercise, unit: .kilograms, distanceUnit: .meters)

        #expect(line == "Set 2 · 100 kg × 8")
        #expect(warmUp == "Warm-up · 100 kg × 8")
    }

    // MARK: - Restoring a rest

    @Test("Test A Rest Still Counting Down Is Re-Armed With Its Start")
    func testRunningRest() {
        let end = start.addingTimeInterval(90)
        #expect(RestRestore.plan(restEnd: end, restStartedAt: start, now: start.addingTimeInterval(30)) == .running(end: end, start: start))
    }

    /// Ended once, on launch: the notification already said so, so nothing is announced twice.
    @Test("Test A Rest That Ran Out While The App Was Gone Is Ended", arguments: [0.0, 600])
    func testEndedRest(lateBy seconds: TimeInterval) {
        let end = start.addingTimeInterval(90)
        #expect(RestRestore.plan(restEnd: end, restStartedAt: start, now: end.addingTimeInterval(seconds)) == .ended(end: end))
    }

    /// A start kept after the rest ran out (so the row reads Ready) is not a rest to restore.
    @Test("Test No End Means No Rest, Whatever The Start")
    func testNoRest() {
        #expect(RestRestore.plan(restEnd: nil, restStartedAt: start, now: start) == .none)
        #expect(RestRestore.plan(restEnd: nil, restStartedAt: nil, now: start) == .none)
    }

    /// A rest written by a build that kept no start still counts down.
    @Test("Test A Rest From An Older Build Restores Without A Start")
    func testRestWithoutStart() {
        let end = start.addingTimeInterval(90)
        #expect(RestRestore.plan(restEnd: end, restStartedAt: nil, now: start) == .running(end: end, start: nil))
    }
}
