//
//  LiveActivityPhaseTests.swift
//  CompoundUnitTests
//
//  The Live Activity's phase derivation (docs/specs/live-activity.md §2).
//

import Testing
import Foundation
@testable import Compound

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)

/// One case per row of the §2 precedence table, plus the five precedence edges called out in §6.
///
/// The derivation is where every behavioural decision in the activity lives — the views are a
/// single switch each — so the whole table is pinned here rather than through the widget.
struct LiveActivityPhaseTests {

    // MARK: - Fixture

    private static let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// A running, mid-workout content state. Every test overrides only the fields its row needs,
    /// so a new field on `ContentState` does not have to be spelled out at thirty call sites.
    private func makeState(
        isActive: Bool = true,
        completedSetsCount: Int = 4,
        totalSetsCount: Int = 12,
        currentExerciseName: String? = "Bench press",
        currentExerciseIndex: Int = 0,
        totalExercisesCount: Int = 3,
        currentExerciseCompletedSetsCount: Int = 1,
        currentExerciseTotalSetsCount: Int = 4,
        targetIsWarmup: Bool = false,
        targetSetId: String? = "set-1",
        targetWeightKg: Double? = 60,
        targetReps: Int? = 8,
        targetDistanceMeters: Double? = nil,
        targetDurationSec: Int? = nil,
        restEndsAt: Date? = nil,
        isWorkoutEnded: Bool = false,
        finalDurationSeconds: TimeInterval? = nil,
        finalVolumeKg: Double? = nil,
        finalCompletedSetsCount: Int? = nil,
        isAllSetsComplete: Bool = false,
        lastLoggedSetId: String? = nil,
        lastLoggedReps: Int? = nil,
        lastLoggedWeightKg: Double? = nil,
        restLeadsToNewExercise: Bool = false
    ) -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            isActive: isActive,
            completedSetsCount: completedSetsCount,
            totalSetsCount: totalSetsCount,
            currentExerciseName: currentExerciseName,
            currentExerciseImageName: nil,
            currentExerciseIndex: currentExerciseIndex,
            totalExercisesCount: totalExercisesCount,
            currentExerciseCompletedSetsCount: currentExerciseCompletedSetsCount,
            currentExerciseTotalSetsCount: currentExerciseTotalSetsCount,
            targetIsWarmup: targetIsWarmup,
            targetSetId: targetSetId,
            targetWeightKg: targetWeightKg,
            targetReps: targetReps,
            targetDistanceMeters: targetDistanceMeters,
            targetDurationSec: targetDurationSec,
            restEndsAt: restEndsAt,
            progress: 0.33,
            isWorkoutEnded: isWorkoutEnded,
            finalDurationSeconds: finalDurationSeconds,
            finalVolumeKg: finalVolumeKg,
            finalCompletedSetsCount: finalCompletedSetsCount,
            isProcessingIntent: false,
            isAllSetsComplete: isAllSetsComplete,
            lastLoggedSetId: lastLoggedSetId,
            lastLoggedReps: lastLoggedReps,
            lastLoggedWeightKg: lastLoggedWeightKg,
            restLeadsToNewExercise: restLeadsToNewExercise
        )
    }

    private func phase(
        _ state: WorkoutActivityAttributes.ContentState,
        isStale: Bool = false
    ) -> LiveActivityPhase {
        LiveActivityPhase(state: state, now: Self.now, isStale: isStale)
    }

    // MARK: - Row 1

    @Test("Test An Ended Workout Derives The Ended Phase Carrying The Final Figures")
    func testAnEndedWorkoutDerivesTheEndedPhaseCarryingTheFinalFigures() {
        let state = makeState(
            isWorkoutEnded: true,
            finalDurationSeconds: 3_600,
            finalVolumeKg: 4_250,
            finalCompletedSetsCount: 12
        )

        #expect(
            phase(state) == .ended(
                Summary(
                    durationSeconds: 3_600,
                    completedSetsCount: 12,
                    volumeKg: 4_250
                )
            )
        )
    }

    // MARK: - Row 2

    @Test("Test An Inactive Workout Derives The Paused Phase")
    func testAnInactiveWorkoutDerivesThePausedPhase() {
        #expect(phase(makeState(isActive: false)) == .paused)
    }

    // MARK: - Row 3

    @Test("Test All Sets Complete Derives The All Sets Done Phase")
    func testAllSetsCompleteDerivesTheAllSetsDonePhase() {
        #expect(phase(makeState(isAllSetsComplete: true)) == .allSetsDone)
    }

    // MARK: - Row 4

    @Test("Test A Rest Still Running Derives The Resting Phase With The Next Target And Logged Set")
    func testARestStillRunningDerivesTheRestingPhaseWithTheNextTargetAndLoggedSet() {
        let restEndsAt = Self.now.addingTimeInterval(60)
        let state = makeState(
            restEndsAt: restEndsAt,
            lastLoggedSetId: "set-1",
            lastLoggedReps: 8,
            lastLoggedWeightKg: 60
        )

        #expect(
            phase(state) == .resting(
                until: restEndsAt,
                next: LiveActivitySetTarget(weightKg: 60, reps: 8),
                logged: LoggedSet(setId: "set-1", reps: 8, weightKg: 60),
                nextExerciseName: nil
            )
        )
    }

    /// The rest after an exercise's last set already points at the next exercise's first set, and
    /// the phase names that exercise so the banner does not read as one more set of the last one.
    @Test("Test A Rest Leading Into A New Exercise Names It")
    func testARestLeadingIntoANewExerciseNamesIt() {
        let restEndsAt = Self.now.addingTimeInterval(60)
        let state = makeState(
            currentExerciseName: "Incline press",
            restEndsAt: restEndsAt,
            lastLoggedSetId: "set-1",
            restLeadsToNewExercise: true
        )

        guard case .resting(_, _, _, let nextExerciseName) = phase(state) else {
            Issue.record("expected .resting, got \(phase(state))"); return
        }
        #expect(nextExerciseName == "Incline press")
    }

    // MARK: - Row 5

    @Test("Test A Rest That Has Passed Derives The Rest Over Phase")
    func testARestThatHasPassedDerivesTheRestOverPhase() {
        let state = makeState(restEndsAt: Self.now.addingTimeInterval(-1))

        #expect(phase(state) == .restOver(next: LiveActivitySetTarget(weightKg: 60, reps: 8)))
    }

    // MARK: - Row 6

    /// A unilateral exercise after the left half of its last pair: the paired counts already say
    /// 4 of 4, but the right row still wants a tap, so the banner stays ready rather than falling
    /// into a phase with no button.
    @Test("Test A Half Finished Last Pair Is Still Ready")
    func testAHalfFinishedLastPairIsStillReady() {
        let state = makeState(
            currentExerciseName: "Single-arm row",
            currentExerciseIndex: 0,
            totalExercisesCount: 3,
            currentExerciseCompletedSetsCount: 3,
            currentExerciseTotalSetsCount: 4,
            targetSetId: "set-4-right"
        )

        guard case .ready(_, let position) = phase(state) else {
            Issue.record("expected .ready, got \(phase(state))"); return
        }
        #expect(position == SetPosition(index: 4, total: 4))
    }

    @Test("Test A Current Target Derives The Ready Phase With A One Based Set Position")
    func testACurrentTargetDerivesTheReadyPhaseWithAOneBasedSetPosition() {
        let state = makeState(currentExerciseCompletedSetsCount: 1, currentExerciseTotalSetsCount: 4)

        #expect(
            phase(state) == .ready(
                target: LiveActivitySetTarget(weightKg: 60, reps: 8),
                position: SetPosition(index: 2, total: 4)
            )
        )
        // The position is what the banner shows as "Set 2 of 4".
        #expect(SetPosition(index: 2, total: 4).label == "Set 2 of 4")
    }

    /// Warm-ups are counted on their own, so the banner says which kind of set is next.
    @Test("Test A Warm Up Target Derives A Warm Up Position")
    func testAWarmUpTargetDerivesAWarmUpPosition() {
        let state = makeState(
            currentExerciseCompletedSetsCount: 0,
            currentExerciseTotalSetsCount: 2,
            targetIsWarmup: true
        )

        guard case .ready(_, let position) = phase(state) else {
            Issue.record("expected .ready, got \(phase(state))"); return
        }
        #expect(position == SetPosition(index: 1, total: 2, isWarmup: true))
        #expect(position.label == "Warmup 1 of 2")
    }

    // MARK: - Row 7

    @Test("Test No Target And No Rest Derives The Unknown Phase")
    func testNoTargetAndNoRestDerivesTheUnknownPhase() {
        let state = makeState(
            currentExerciseName: nil,
            currentExerciseCompletedSetsCount: 1,
            currentExerciseTotalSetsCount: 4,
            targetSetId: nil,
            targetWeightKg: nil,
            targetReps: nil
        )

        #expect(phase(state) == .unknown)
    }

    // MARK: - Precedence edges (§6)

    @Test("Test Ended Beats Paused")
    func testEndedBeatsPaused() {
        let state = makeState(isActive: false, isWorkoutEnded: true, finalCompletedSetsCount: 12)

        #expect(phase(state) == .ended(Summary(completedSetsCount: 12)))
    }

    @Test("Test Paused Beats Resting")
    func testPausedBeatsResting() {
        let state = makeState(isActive: false, restEndsAt: Self.now.addingTimeInterval(60))

        #expect(phase(state) == .paused)
    }

    @Test("Test A Stale Activity With A Live Rest Still Gives Rest Over")
    func testAStaleActivityWithALiveRestStillGivesRestOver() {
        let state = makeState(restEndsAt: Self.now.addingTimeInterval(60), lastLoggedSetId: "set-1")

        #expect(phase(state, isStale: true) == .restOver(next: LiveActivitySetTarget(weightKg: 60, reps: 8)))
    }

    @Test("Test A Rest With No Logged Set Gives Resting With A Nil Logged Set")
    func testARestWithNoLoggedSetGivesRestingWithANilLoggedSet() {
        let restEndsAt = Self.now.addingTimeInterval(45)
        let state = makeState(restEndsAt: restEndsAt, lastLoggedSetId: nil)

        #expect(
            phase(state) == .resting(
                until: restEndsAt,
                next: LiveActivitySetTarget(weightKg: 60, reps: 8),
                logged: nil,
                nextExerciseName: nil
            )
        )
    }

    @Test("Test The Last Exercise With All Its Sets Done Gives All Sets Done Not Exercise Done")
    func testTheLastExerciseWithAllItsSetsDoneGivesAllSetsDoneNotExerciseDone() {
        let state = makeState(
            currentExerciseIndex: 2,
            totalExercisesCount: 3,
            currentExerciseCompletedSetsCount: 4,
            currentExerciseTotalSetsCount: 4,
            isAllSetsComplete: true
        )

        #expect(phase(state) == .allSetsDone)
    }

    @Test("Test Resting Carries No Next Target When Every Target Field Is Empty")
    func testRestingCarriesNoNextTargetWhenEveryTargetFieldIsEmpty() {
        let restEndsAt = Self.now.addingTimeInterval(30)
        let state = makeState(
            targetSetId: nil,
            targetWeightKg: nil,
            targetReps: nil,
            restEndsAt: restEndsAt
        )

        #expect(phase(state) == .resting(until: restEndsAt, next: nil, logged: nil, nextExerciseName: nil))
    }
}

#endif
