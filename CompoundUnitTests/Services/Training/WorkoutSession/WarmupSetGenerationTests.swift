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
/// Two judgements are encoded here and neither is obvious from reading the call site: how many
/// warm-ups a weight deserves, and what weight each one should be. A heavy squat wants a full ramp;
/// a light accessory lift wants one set, not three that waste the session.
@MainActor
struct WarmupSetGenerationTests {

    private func warmups(
        weight: Double?,
        reps: Int? = 8,
        mode: TrackingMode = .weightReps,
        targets: [SetTarget] = []
    ) -> [WorkoutSetModel] {
        WorkoutSessionModel.generateWarmupSets(
            trackingMode: mode,
            authorId: "author-1",
            workingWeightKg: weight,
            workingReps: reps,
            setTargets: targets
        )
    }

    // MARK: - How many

    /// A light lift does not need a ramp — one set to feel the movement is enough.
    @Test("Test A Light Weight Gets One Warm-Up")
    func testALightWeightGetsOneWarmUp() {
        #expect(warmups(weight: 20).count == 1)
        #expect(warmups(weight: 49.9).count == 1)
    }

    @Test("Test A Moderate Weight Gets Two Warm-Ups")
    func testAModerateWeightGetsTwoWarmUps() {
        #expect(warmups(weight: 50).count == 2)
        #expect(warmups(weight: 99.9).count == 2)
    }

    @Test("Test A Heavy Weight Gets The Full Ramp")
    func testAHeavyWeightGetsTheFullRamp() {
        #expect(warmups(weight: 100).count == 3)
        #expect(warmups(weight: 200).count == 3)
    }

    /// With nothing to go on, two is the middle answer rather than none.
    @Test("Test An Unknown Weight Gets Two Warm-Ups")
    func testAnUnknownWeightGetsTwoWarmUps() {
        #expect(warmups(weight: nil).count == 2)
        #expect(warmups(weight: 0).count == 2)
    }

    // MARK: - What weight

    /// Half, then seventy per cent, then ninety — the ramp is in the percentages, not the reps.
    @Test("Test Warm-Ups Ramp Up To The Working Weight")
    func testWarmUpsRampUpToTheWorkingWeight() {
        let sets = warmups(weight: 100)

        #expect(sets.count == 3)
        #expect(sets[0].weightKg == 50)
        #expect(sets[1].weightKg == 70)
        #expect(sets[2].weightKg == 90)
    }

    @Test("Test A Two-Set Ramp Takes The First Two Percentages")
    func testATwoSetRampTakesTheFirstTwoPercentages() {
        let sets = warmups(weight: 60)

        #expect(sets.map(\.weightKg) == [30, 42])
    }

    @Test("Test A One-Set Ramp Is Half The Working Weight")
    func testAOneSetRampIsHalfTheWorkingWeight() {
        #expect(warmups(weight: 40).map(\.weightKg) == [20])
    }

    /// Every warm-up is below the working weight, or it is not a warm-up.
    @Test("Test Every Warm-Up Is Lighter Than The Working Set")
    func testEveryWarmUpIsLighterThanTheWorkingSet() {
        for working in [30.0, 60.0, 100.0, 180.0] {
            for set in warmups(weight: working) {
                let weight = set.weightKg ?? 0
                #expect(weight < working)
                #expect(weight > 0)
            }
        }
    }

    @Test("Test Warm-Ups Get Heavier In Order")
    func testWarmUpsGetHeavierInOrder() {
        let weights = warmups(weight: 120).compactMap(\.weightKg)

        #expect(weights == weights.sorted())
        #expect(Set(weights).count == weights.count)
    }

    @Test("Test An Unknown Working Weight Leaves The Warm-Ups Blank")
    func testAnUnknownWorkingWeightLeavesTheWarmUpsBlank() {
        let sets = warmups(weight: nil)
        let allBlank = sets.allSatisfy { $0.weightKg == nil }

        #expect(allBlank)
    }

    // MARK: - Shape of the sets

    @Test("Test Warm-Ups Are Marked As Warm-Ups")
    func testWarmUpsAreMarkedAsWarmUps() {
        let allWarmups = warmups(weight: 100).allSatisfy(\.isWarmup)

        #expect(allWarmups)
    }

    @Test("Test Warm-Ups Are Numbered From One And Not Yet Done")
    func testWarmUpsAreNumberedFromOneAndNotYetDone() {
        let sets = warmups(weight: 100)

        let noneDone = sets.allSatisfy { $0.completedAt == nil }

        #expect(sets.map(\.index) == [1, 2, 3])
        #expect(noneDone)
        #expect(Set(sets.map(\.id)).count == sets.count)
    }

    @Test("Test Warm-Ups Take The Working Reps")
    func testWarmUpsTakeTheWorkingReps() {
        let allFives = warmups(weight: 100, reps: 5).allSatisfy { $0.reps == 5 }

        #expect(allFives)
    }

    /// With no reps from last time, the target from the programme is the next best thing.
    @Test("Test Reps Fall Back To The Set Target")
    func testRepsFallBackToTheSetTarget() {
        let targets = [SetTarget(setNumber: 1, minReps: 6, maxReps: 10)]
        let sets = warmups(weight: 100, reps: nil, targets: targets)
        let allSixes = sets.allSatisfy { $0.reps == 6 }

        #expect(allSixes)
    }

    @Test("Test Reps Can Be Unknown")
    func testRepsCanBeUnknown() {
        let noneSet = warmups(weight: 100, reps: nil).allSatisfy { $0.reps == nil }

        #expect(noneSet)
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
