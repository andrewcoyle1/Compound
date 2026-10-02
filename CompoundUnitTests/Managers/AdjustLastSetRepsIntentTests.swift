//
//  AdjustLastSetRepsIntentTests.swift
//  CompoundUnitTests
//
//  The rep correction offered during a rest (docs/specs/live-activity.md §4).
//

import Testing
import Foundation
@testable import Compound

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)

/// `CompleteSetIntent` logs the prescribed reps, so a set that fell short is recorded as a hit and
/// smart progression reads it as one. The correction window is what fixes that, and it is open in
/// exactly one place: the rest that follows the set, while the number is still fresh.
///
/// A real `Activity` cannot be started in a test process, so the intent body is a thin wrapper and
/// everything that decides anything lives in `AdjustLastSetRepsDecision`. What the app then does
/// with the correction is `LiveActivityIntentHandlerTests`; the shared-storage slot the v1
/// hand-off wrote survives only as the fallback for a process with no handler registered.
struct AdjustLastSetRepsIntentTests {

    private static let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeState(
        restEndsAt: Date? = now.addingTimeInterval(60),
        lastLoggedSetId: String? = "set-1",
        lastLoggedReps: Int? = 8
    ) -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            isActive: true,
            completedSetsCount: 4,
            totalSetsCount: 12,
            currentExerciseName: "Bench press",
            currentExerciseImageName: nil,
            currentExerciseIndex: 0,
            totalExercisesCount: 3,
            currentExerciseCompletedSetsCount: 1,
            currentExerciseTotalSetsCount: 4,
            targetSetId: "set-2",
            targetWeightKg: 60,
            targetReps: 8,
            targetDistanceMeters: nil,
            targetDurationSec: nil,
            restEndsAt: restEndsAt,
            progress: 0.33,
            isWorkoutEnded: false,
            finalDurationSeconds: nil,
            finalVolumeKg: nil,
            finalCompletedSetsCount: nil,
            isProcessingIntent: false,
            isAllSetsComplete: false,
            lastLoggedSetId: lastLoggedSetId,
            lastLoggedReps: lastLoggedReps,
            lastLoggedWeightKg: 60
        )
    }

    private func reps(
        _ state: WorkoutActivityAttributes.ContentState,
        delta: Int,
        now: Date = AdjustLastSetRepsIntentTests.now
    ) -> Int? {
        AdjustLastSetRepsDecision.adjustedReps(state: state, now: now, delta: delta)
    }

    // MARK: - The window

    @Test("Test A Correction During The Rest Applies The Delta")
    func testACorrectionDuringTheRestAppliesTheDelta() {
        #expect(reps(makeState(), delta: -1) == 7)
        #expect(reps(makeState(), delta: 1) == 9)
    }

    /// Without a logged set there is nothing to correct — the rest may have been started from the
    /// app for a set logged there.
    @Test("Test There Is Nothing To Correct Without A Logged Set")
    func testThereIsNothingToCorrectWithoutALoggedSet() {
        #expect(reps(makeState(lastLoggedSetId: nil), delta: -1) == nil)
    }

    /// The window closes with the rest: once it has run out the next set is what is on screen, and
    /// a stray tap must not rewrite the last one.
    @Test("Test The Window Closes When The Rest Ends")
    func testTheWindowClosesWhenTheRestEnds() {
        #expect(reps(makeState(restEndsAt: Self.now.addingTimeInterval(-1)), delta: -1) == nil)
        #expect(reps(makeState(restEndsAt: nil), delta: -1) == nil)
    }

    // MARK: - Clamping

    @Test("Test The Corrected Reps Are Clamped To Zero And Ninety Nine")
    func testTheCorrectedRepsAreClampedToZeroAndNinetyNine() {
        #expect(reps(makeState(lastLoggedReps: 0), delta: -1) == 0)
        #expect(reps(makeState(lastLoggedReps: 99), delta: 1) == 99)
        // A logged set with no rep count at all counts up from zero rather than dropping the tap.
        #expect(reps(makeState(lastLoggedReps: nil), delta: 1) == 1)
    }

}

#endif
