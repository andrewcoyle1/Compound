//
//  WarmupSetGenerationTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The warm-up sets the app offers before the working sets.
///
/// Three judgements are encoded here and none is obvious from reading the call site: how many
/// warm-ups the work deserves, what weight each one is, and how many reps. Heavy, low-rep work
/// wants a full ramp; a light accessory lift wants one set. Reps fall as the load rises (8, 5, 3),
/// so the last warm-up primes the working weight without being an extra working set.
@MainActor
struct WarmupSetGenerationTests {

    private func warmups(
        weight: Double?,
        reps: Int? = 8,
        mode: TrackingMode = .weightReps,
        targets: [SetTarget] = [],
        exercise: ExerciseModel? = nil,
        count: Int? = nil
    ) -> [WorkoutSetModel] {
        WorkoutSessionModel.generateWarmupSets(
            trackingMode: mode,
            authorId: "author-1",
            workingWeightKg: weight,
            workingReps: reps,
            setTargets: targets,
            exercise: exercise,
            count: count
        )
    }

    /// Each warm-up's weight as a whole percentage of a 100 kg working weight.
    private func percentages(reps: Int? = 8, count: Int?) -> [Int] {
        warmups(weight: 100, reps: reps, count: count).map { Int(($0.weightKg ?? 0).rounded()) }
    }

    private func exercise(type: ExerciseType) -> ExerciseModel {
        ExerciseModel(
            id: "lift", authorId: "author-1", name: "Lift", trackableMetrics: [.weight, .reps], type: type,
            laterality: .bilateral, muscleGroups: [.sideDelts: .primary], isBodyweight: false,
            rangeOfMotion: 4, stability: 4, bodyWeightContribution: 0, alternateNames: []
        )
    }

    // MARK: - How many

    /// Heavy work (six reps or fewer, about 83 % of a max or more) gets the full ramp.
    @Test("Test Heavy Low-Rep Work Gets Three Warm-Ups")
    func testHeavyLowRepWorkGetsThreeWarmUps() {
        #expect(warmups(weight: 100, reps: 5).count == 3)
        #expect(warmups(weight: 100, reps: 6).count == 3)
    }

    @Test("Test Moderate Work Gets Two Warm-Ups")
    func testModerateWorkGetsTwoWarmUps() {
        #expect(warmups(weight: 100, reps: 7).count == 2)
        #expect(warmups(weight: 100, reps: 12).count == 2)
    }

    /// Light, high-rep work is far from the lifter's max, so one set to feel the movement is enough.
    @Test("Test Light High-Rep Work Gets One Warm-Up")
    func testLightHighRepWorkGetsOneWarmUp() {
        #expect(warmups(weight: 100, reps: 15).count == 1)
    }

    /// The count follows the work relative to the lifter, not the kilograms on the bar.
    @Test("Test The Count Does Not Depend On The Weight")
    func testTheCountDoesNotDependOnTheWeight() {
        #expect(warmups(weight: 40, reps: 5).count == 3)
        #expect(warmups(weight: 200, reps: 15).count == 1)
    }

    /// Isolation and core work needs one warm-up, however heavy.
    @Test("Test Isolation Work Gets One Warm-Up")
    func testIsolationWorkGetsOneWarmUp() {
        #expect(warmups(weight: 30, reps: 5, exercise: exercise(type: .isolationUpper)).count == 1)
        #expect(warmups(weight: 30, reps: 5, exercise: exercise(type: .core)).count == 1)
    }

    /// With no reps to go on, two is the middle answer rather than none.
    @Test("Test Unknown Reps Get Two Warm-Ups")
    func testUnknownRepsGetTwoWarmUps() {
        #expect(warmups(weight: 100, reps: nil).count == 2)
        #expect(warmups(weight: nil, reps: nil).count == 2)
    }

    // MARK: - What weight

    /// About 45, 65 and 82 % for a full ramp.
    @Test("Test Warm-Ups Ramp Up To The Working Weight")
    func testWarmUpsRampUpToTheWorkingWeight() {
        #expect(warmups(weight: 100, reps: 5).map(\.weightKg) == [45, 65, 82])
    }

    @Test("Test A Two-Set Ramp Is Half And Three Quarters")
    func testATwoSetRampIsHalfAndThreeQuarters() {
        #expect(warmups(weight: 60).map(\.weightKg) == [30, 45])
    }

    @Test("Test A One-Set Ramp Is Sixty Percent")
    func testAOneSetRampIsSixtyPercent() {
        #expect(warmups(weight: 40, reps: 15).map(\.weightKg) == [24])
    }

    /// Every warm-up is below the working weight, or it is not a warm-up.
    @Test("Test Every Warm-Up Is Lighter Than The Working Set")
    func testEveryWarmUpIsLighterThanTheWorkingSet() {
        for working in [30.0, 60.0, 100.0, 180.0] {
            for reps in [3, 8, 15] {
                for set in warmups(weight: working, reps: reps) {
                    let weight = set.weightKg ?? 0
                    #expect(weight < working)
                    #expect(weight > 0)
                }
            }
        }
    }

    @Test("Test Warm-Ups Get Heavier In Order")
    func testWarmUpsGetHeavierInOrder() {
        let weights = warmups(weight: 120, reps: 5).compactMap(\.weightKg)

        #expect(weights == weights.sorted())
        #expect(Set(weights).count == weights.count)
    }

    @Test("Test An Unknown Working Weight Leaves The Warm-Ups Blank")
    func testAnUnknownWorkingWeightLeavesTheWarmUpsBlank() {
        let sets = warmups(weight: nil)
        let allBlank = sets.allSatisfy { $0.weightKg == nil }

        #expect(allBlank)
    }

    // MARK: - How many reps

    /// Reps taper as the load rises: 8 at up to half the working weight, 5 up to 70 %, 3 up to 85 %.
    @Test("Test Warm-Up Reps Taper As The Load Rises")
    func testWarmUpRepsTaper() {
        #expect(warmups(weight: 100, reps: 5).map(\.reps) == [8, 5, 3])
        #expect(warmups(weight: 100, reps: 10).map(\.reps) == [8, 3])
        #expect(WorkoutSessionModel.warmupReps(percentage: 0.9) == 2)
    }

    /// The taper does not depend on the working reps: a triple still warms up with eight light reps.
    @Test("Test The Taper Ignores The Working Reps")
    func testTheTaperIgnoresTheWorkingReps() {
        #expect(warmups(weight: 100, reps: 3).map(\.reps) == [8, 5, 3])
        #expect(warmups(weight: 100, reps: nil).map(\.reps) == [8, 3])
    }

    /// Bodyweight work has no load to taper against, so it warms up at the working reps, or the
    /// programme's target when there are none from last time.
    @Test("Test Bodyweight Warm-Ups Take The Working Reps")
    func testBodyweightWarmUpsTakeTheWorkingReps() {
        let allTens = warmups(weight: nil, reps: 10, mode: .repsOnly).allSatisfy { $0.reps == 10 }
        #expect(allTens)

        let targets = [SetTarget(setNumber: 1, minReps: 6, maxReps: 10)]
        let allSixes = warmups(weight: nil, reps: nil, mode: .repsOnly, targets: targets).allSatisfy { $0.reps == 6 }
        #expect(allSixes)
    }

    // MARK: - Shape of the sets

    @Test("Test Warm-Ups Are Marked As Warm-Ups")
    func testWarmUpsAreMarkedAsWarmUps() {
        let allWarmups = warmups(weight: 100).allSatisfy(\.isWarmup)

        #expect(allWarmups)
    }

    @Test("Test Warm-Ups Are Numbered From One And Not Yet Done")
    func testWarmUpsAreNumberedFromOneAndNotYetDone() {
        let sets = warmups(weight: 100, reps: 5)

        let noneDone = sets.allSatisfy { $0.completedAt == nil }

        #expect(sets.map(\.index) == [1, 2, 3])
        #expect(noneDone)
        #expect(Set(sets.map(\.id)).count == sets.count)
    }

    // MARK: - A count from the plan

    /// The plan's warm-up count overrides the rule, each count with its own ramp; past four, each
    /// extra set is another at 90 %.
    @Test(
        "Test A Planned Warm-Up Count Sets The Ramp",
        arguments: [
            (0, [Int]()),
            (1, [60]),
            (2, [50, 75]),
            (3, [45, 65, 82]),
            (4, [45, 60, 75, 85]),
            (5, [45, 60, 75, 85, 90])
        ]
    )
    func testAPlannedWarmUpCountSetsTheRamp(count: Int, expected: [Int]) {
        #expect(percentages(count: count) == expected)
    }

    /// A planned count is the user's choice: light work keeps every warm-up the plan asks for.
    @Test("Test A Planned Count Is Kept Whole")
    func testAPlannedCountIsKeptWhole() {
        #expect(warmups(weight: 20, reps: 15, count: 3).count == 3)
        #expect(warmups(weight: 100, mode: .timeOnly, count: 3).isEmpty)
        #expect(warmups(weight: 100, reps: 5, count: 4).map(\.reps) == [8, 5, 3, 3])
    }

    // MARK: - When there are none

    /// A plank or a run has no weight to ramp up to, so a warm-up set would be meaningless.
    @Test("Test Timed And Distance Work Gets No Warm-Ups")
    func testTimedAndDistanceWorkGetsNoWarmUps() {
        #expect(warmups(weight: 100, mode: .timeOnly).isEmpty)
        #expect(warmups(weight: 100, mode: .distanceTime).isEmpty)
    }

    /// Bodyweight work still ramps: the reps matter even when the load does not change.
    @Test("Test Bodyweight Work Still Gets Warm-Ups")
    func testBodyweightWorkStillGetsWarmUps() {
        #expect(!warmups(weight: nil, mode: .repsOnly).isEmpty)
    }
}
