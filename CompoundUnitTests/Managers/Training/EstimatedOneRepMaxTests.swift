//
//  EstimatedOneRepMaxTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The app's one estimate of a one-rep max (`ExerciseOneRMAggregator.estimated1RM`), which every
/// screen, record and the coach's port read. `functions/coach-maths.test.js` checks the same rules.
///
/// - **A single is its own max**, not 3 % more, so a lighter single cannot beat a heavier one.
/// - **Reps in reserve count**: the reps you could have done, read from the RPE.
/// - **No estimate past ten reps to failure** (Reynolds 2006): the set still exists, but no
///   equation is trustworthy there.
struct EstimatedOneRepMaxTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func set(_ kg: Double?, _ reps: Int?, rpe: Double? = nil, warmup: Bool = false) -> WorkoutSetModel {
        WorkoutSetModel(
            id: UUID().uuidString, authorId: "author-1", index: 1, reps: reps, weightKg: kg, rpe: rpe,
            isWarmup: warmup, completedAt: start, dateCreated: start
        )
    }

    @Test("Test A Single Is Its Own Max")
    func testASingleIsItsOwnMax() {
        #expect(ExerciseOneRMAggregator.estimated1RM(weightKg: 100, reps: 1) == 100)
        #expect(ExerciseOneRMAggregator.estimated1RM(weightKg: 100, reps: 1, rpe: 10) == 100)
        // A weight logged with no reps reads as a single.
        #expect(ExerciseOneRMAggregator.estimated1RM(of: set(100, nil)) == 100)
    }

    @Test("Test Epley Below The Cap")
    func testEpleyBelowTheCap() throws {
        let six = try #require(ExerciseOneRMAggregator.estimated1RM(weightKg: 100, reps: 6))
        #expect(abs(six - 120) < 1e-9)
        let ten = try #require(ExerciseOneRMAggregator.estimated1RM(weightKg: 90, reps: 10))
        #expect(abs(ten - 120) < 1e-9)
    }

    /// Eight reps at RPE 8 is ten reps to failure; a single at RPE 8 is three.
    @Test("Test Reps In Reserve Are Read From The RPE")
    func testRepsInReserveAreReadFromTheRPE() throws {
        let eight = try #require(ExerciseOneRMAggregator.estimated1RM(of: set(90, 8, rpe: 8)))
        #expect(abs(eight - 120) < 1e-9)
        let single = try #require(ExerciseOneRMAggregator.estimated1RM(of: set(100, 1, rpe: 8)))
        #expect(abs(single - 110) < 1e-9)
        #expect(ExerciseOneRMAggregator.repsToFailure(reps: 5, rpe: nil) == 5)
    }

    @Test("Test Nothing Is Estimated Past Ten Reps To Failure")
    func testNothingPastTenRepsToFailure() {
        #expect(ExerciseOneRMAggregator.estimated1RM(weightKg: 60, reps: 11) == nil)
        #expect(ExerciseOneRMAggregator.estimated1RM(weightKg: 60, reps: 9, rpe: 8) == nil)
        #expect(ExerciseOneRMAggregator.estimated1RM(weightKg: 0, reps: 5) == nil)
        #expect(ExerciseOneRMAggregator.estimated1RM(of: set(nil, 5)) == nil)
    }

    /// The aggregate behind the Progress tab skips a set past the cap rather than inflating it, and
    /// an exercise done only in long sets has no figure at all.
    @Test("Test The Aggregate Leaves Long Sets Out")
    func testTheAggregateLeavesLongSetsOut() {
        let bench = WorkoutExerciseModel(
            id: "e1", authorId: "author-1", templateId: "bench", name: "Bench", trackingMode: .weightReps, index: 1,
            sets: [set(100, 5), set(80, 15)]
        )
        let curl = WorkoutExerciseModel(
            id: "e2", authorId: "author-1", templateId: "curl", name: "Curl", trackingMode: .weightReps, index: 2,
            sets: [set(15, 12)]
        )
        let session = WorkoutSessionModel(id: "s", authorId: "author-1", name: "Push", dateCreated: start, endedAt: start, exercises: [bench, curl])

        let aggregate = ExerciseOneRMAggregator.aggregate(sessions: [session])

        #expect(abs((aggregate["bench"]?.latest1RM ?? 0) - 100 * (1 + 5.0 / 30)) < 1e-9)
        #expect(aggregate["curl"] == nil)
    }

    /// The load for a number of reps with some in reserve is Epley turned round.
    @Test("Test The Load Is Epley Inverted")
    func testTheLoadIsEpleyInverted() {
        #expect(abs(ExerciseOneRMAggregator.load(forOneRepMax: 120, reps: 8, reserve: 2) - 90) < 1e-9)
        #expect(ExerciseOneRMAggregator.load(forOneRepMax: 120, reps: 1, reserve: 0) == 120)
    }
}
