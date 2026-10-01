//
//  TargetProposalTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The propose-and-confirm half of adaptive expenditure: when the app should ask to move the
/// calorie target, what it should ask for, and when it should keep quiet.
struct TargetProposalTests {

    // MARK: - Fixtures

    private func estimate(
        kcal: Double,
        isProvisional: Bool = false,
        weeklyTrendChangeKg: Double? = nil
    ) -> ExpenditureEstimate {
        ExpenditureEstimate(
            day: Date(timeIntervalSince1970: 1_750_000_000),
            kcal: kcal,
            source: isProvisional ? .prior : .adaptive,
            isProvisional: isProvisional,
            trendWeightKg: 80,
            weeklyTrendChangeKg: weeklyTrendChangeKg,
            loggedDays: 24,
            weighInCount: 20,
            windowDays: 28,
            stepAdjustmentKcal: 0
        )
    }

    private func plan(targetKcal: Double, floor: CalorieFloor = .standard) -> DietPlan {
        DietPlan(
            planId: "plan-1",
            userId: "user-1",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            tdeeEstimate: targetKcal,
            preferredDiet: PreferredDiet.balanced.rawValue,
            calorieFloor: floor.rawValue,
            trainingType: "moderate",
            calorieDistribution: CalorieDistribution.even.rawValue,
            proteinIntake: ProteinIntake.moderate.rawValue,
            days: (0..<7).map { _ in
                DailyMacroTarget(calories: targetKcal, proteinGrams: 150, carbGrams: 200, fatGrams: 70)
            }
        )
    }

    /// A loss goal at `weeklyKg` per week. The model stores a magnitude and puts the direction in
    /// the two weights, which is what `signedWeeklyChangeKg` reads back out.
    private func lossGoal(weeklyKg: Double = 0.5, status: WeightGoal.GoalStatus = .active) -> WeightGoal {
        WeightGoal(
            userId: "user-1",
            objective: .loseWeight,
            startingWeightKg: 85,
            targetWeightKg: 78,
            weeklyChangeKg: weeklyKg,
            status: status
        )
    }

    private func settings(
        mode: ExpenditureCalculationMode = .dynamic,
        predictive: Bool = false
    ) -> NutritionStrategySettings {
        var settings = NutritionStrategySettings(authorId: "user-1")
        settings.calculationMode = mode
        settings.predictiveGoalAdjustments = predictive
        return settings
    }

    // MARK: - When there is nothing to say

    @Test("Test No Proposal Without A Plan")
    func testNoProposalWithoutAPlan() {
        let proposal = TargetProposal.make(
            estimate: estimate(kcal: 2800),
            plan: nil,
            goal: nil,
            settings: settings()
        )

        #expect(proposal == nil)
    }

    @Test("Test No Proposal While The Estimate Is Provisional")
    func testNoProposalWhileTheEstimateIsProvisional() {
        let proposal = TargetProposal.make(
            estimate: estimate(kcal: 2800, isProvisional: true),
            plan: plan(targetKcal: 2000),
            goal: nil,
            settings: settings()
        )

        #expect(proposal == nil)
    }

    @Test("Test No Proposal Under Fixed Mode")
    func testNoProposalUnderFixedMode() {
        let proposal = TargetProposal.make(
            estimate: estimate(kcal: 2800),
            plan: plan(targetKcal: 2000),
            goal: nil,
            settings: settings(mode: .fixed)
        )

        #expect(proposal == nil)
    }

    @Test("Test A Move Smaller Than Fifty Kcal Is Not Worth A Tap")
    func testAMoveSmallerThanFiftyKcalIsNotWorthATap() {
        let proposal = TargetProposal.make(
            estimate: estimate(kcal: 2040),
            plan: plan(targetKcal: 2000),
            goal: nil,
            settings: settings()
        )

        #expect(proposal == nil)
    }

    // MARK: - What it proposes

    @Test("Test With No Active Goal The Proposal Is Maintenance")
    func testWithNoActiveGoalTheProposalIsMaintenance() throws {
        let proposal = try #require(
            TargetProposal.make(
                estimate: estimate(kcal: 2800),
                plan: plan(targetKcal: 2000),
                goal: nil,
                settings: settings()
            )
        )

        #expect(proposal.proposedTargetKcal == 2800)
        #expect(proposal.expenditureKcal == 2800)
        #expect(proposal.currentTargetKcal == 2000)
        #expect(proposal.goalWeeklyChangeKg == nil)
        #expect(proposal.reason == .expenditureMoved)
    }

    @Test("Test A Paused Goal Does Not Count As A Goal")
    func testAPausedGoalDoesNotCountAsAGoal() throws {
        let proposal = try #require(
            TargetProposal.make(
                estimate: estimate(kcal: 2800),
                plan: plan(targetKcal: 2000),
                goal: lossGoal(status: .paused),
                settings: settings()
            )
        )

        #expect(proposal.proposedTargetKcal == 2800)
        #expect(proposal.goalWeeklyChangeKg == nil)
    }

    @Test("Test A Half Kilo A Week Loss Goal Takes Five Hundred And Fifty Off")
    func testAHalfKiloAWeekLossGoalTakesFiveHundredAndFiftyOff() throws {
        let proposal = try #require(
            TargetProposal.make(
                estimate: estimate(kcal: 2800),
                plan: plan(targetKcal: 2000),
                goal: lossGoal(),
                settings: settings()
            )
        )

        #expect(proposal.proposedTargetKcal == 2250)
        #expect(proposal.goalWeeklyChangeKg == -0.5)
    }

    // MARK: - The predictive correction

    @Test("Test A Rate Behind The Goal Nudges The Target Down")
    func testARateBehindTheGoalNudgesTheTargetDown() throws {
        // Goal is −0.5 kg/wk, the scale is only doing −0.4, so the target comes down by
        // (−0.5 − −0.4) · 7700 / 7 = −110.
        let proposal = try #require(
            TargetProposal.make(
                estimate: estimate(kcal: 2800, weeklyTrendChangeKg: -0.4),
                plan: plan(targetKcal: 2000),
                goal: lossGoal(),
                settings: settings(predictive: true)
            )
        )

        #expect(proposal.proposedTargetKcal == 2140)
        #expect(proposal.weeklyTrendChangeKg == -0.4)
    }

    @Test("Test The Predictive Correction Is Clamped At Two Hundred Kcal")
    func testThePredictiveCorrectionIsClampedAtTwoHundredKcal() throws {
        // A raw correction of (−0.5 − 1.5) · 7700 / 7 = −2200, which is the algorithm arguing
        // with the goal rather than serving it.
        let proposal = try #require(
            TargetProposal.make(
                estimate: estimate(kcal: 2800, weeklyTrendChangeKg: 1.5),
                plan: plan(targetKcal: 2000),
                goal: lossGoal(),
                settings: settings(predictive: true)
            )
        )

        #expect(proposal.proposedTargetKcal == 2250 - TargetProposal.maximumCorrectionKcal)
    }

    @Test("Test The Correction Is Skipped When Predictive Adjustments Are Off")
    func testTheCorrectionIsSkippedWhenPredictiveAdjustmentsAreOff() throws {
        let proposal = try #require(
            TargetProposal.make(
                estimate: estimate(kcal: 2800, weeklyTrendChangeKg: -0.1),
                plan: plan(targetKcal: 2000),
                goal: lossGoal(),
                settings: settings(predictive: false)
            )
        )

        #expect(proposal.proposedTargetKcal == 2250)
    }

    @Test("Test A Proposal The Correction Alone Earned Says So")
    func testAProposalTheCorrectionAloneEarnedSaysSo() throws {
        // Without the correction the move is 20 kcal — too small to show. The correction of
        // (−0.5 − −0.4) · 7700 / 7 = −110 is what makes it worth saying.
        let proposal = try #require(
            TargetProposal.make(
                estimate: estimate(kcal: 2820, weeklyTrendChangeKg: -0.4),
                plan: plan(targetKcal: 2270),
                goal: lossGoal(),
                settings: settings(predictive: true)
            )
        )

        #expect(proposal.reason == .rateOffTarget)
        #expect(proposal.proposedTargetKcal == 2160)
    }

    // MARK: - The floor

    @Test("Test The Plan's Calorie Floor Holds The Proposal Up")
    func testThePlansCalorieFloorHoldsTheProposalUp() throws {
        // 1400 expenditure against a 1 kg/wk loss goal would propose 300 kcal a day.
        let steepGoal = WeightGoal(
            userId: "user-1",
            objective: .loseWeight,
            startingWeightKg: 85,
            targetWeightKg: 70,
            weeklyChangeKg: 1.0,
            status: .active
        )
        let proposal = try #require(
            TargetProposal.make(
                estimate: estimate(kcal: 1400),
                plan: plan(targetKcal: 2000, floor: .standard),
                goal: steepGoal,
                settings: settings()
            )
        )

        #expect(proposal.proposedTargetKcal == CalorieFloor.standard.minimumValue)
    }

    @Test("Test A Low Floor Lets The Proposal Go Lower")
    func testALowFloorLetsTheProposalGoLower() throws {
        let steepGoal = WeightGoal(
            userId: "user-1",
            objective: .loseWeight,
            startingWeightKg: 85,
            targetWeightKg: 70,
            weeklyChangeKg: 1.0,
            status: .active
        )
        let proposal = try #require(
            TargetProposal.make(
                estimate: estimate(kcal: 1400),
                plan: plan(targetKcal: 2000, floor: .low),
                goal: steepGoal,
                settings: settings()
            )
        )

        #expect(proposal.proposedTargetKcal == CalorieFloor.low.minimumValue)
    }

    // MARK: - Dismissal

    @Test("Test A Dismissed Figure Stays Dismissed")
    func testADismissedFigureStaysDismissed() {
        let proposal = TargetProposal.make(
            estimate: estimate(kcal: 2800),
            plan: plan(targetKcal: 2000),
            goal: nil,
            settings: settings(),
            dismissedKcal: 2790
        )

        #expect(proposal == nil)
    }

    @Test("Test A Dismissed Figure Comes Back Once It Has Moved Fifty Kcal")
    func testADismissedFigureComesBackOnceItHasMovedFiftyKcal() throws {
        let proposal = try #require(
            TargetProposal.make(
                estimate: estimate(kcal: 2800),
                plan: plan(targetKcal: 2000),
                goal: nil,
                settings: settings(),
                dismissedKcal: 2700
            )
        )

        #expect(proposal.proposedTargetKcal == 2800)
    }

    /// Two people on one device, or one person with two accounts: a dismissal belongs to whoever
    /// made it, or the second account never sees a card it was never shown.
    @Test("Test The Dismissed Key Is Scoped Per Account")
    func testTheDismissedKeyIsScopedPerAccount() {
        let mine = TargetProposal.dismissedDefaultsKey(userId: "user-1")
        let theirs = TargetProposal.dismissedDefaultsKey(userId: "user-2")

        #expect(mine != theirs)
        #expect(mine.hasPrefix(TargetProposal.dismissedDefaultsKeyPrefix))
        #expect(theirs.hasPrefix(TargetProposal.dismissedDefaultsKeyPrefix))
    }

    /// Before sign-in there is no plan to propose against, so the bare prefix is a fine home for a
    /// dismissal that cannot happen.
    @Test("Test A Missing User Id Falls Back To The Bare Prefix")
    func testAMissingUserIdFallsBackToTheBarePrefix() {
        #expect(TargetProposal.dismissedDefaultsKey(userId: nil) == TargetProposal.dismissedDefaultsKeyPrefix)
        #expect(TargetProposal.dismissedDefaultsKey(userId: "") == TargetProposal.dismissedDefaultsKeyPrefix)
    }

    // MARK: - The signed goal rate

    @Test("Test A Goal's Weekly Change Takes Its Sign From Its Two Weights")
    func testAGoalsWeeklyChangeTakesItsSignFromItsTwoWeights() {
        let loss = lossGoal(weeklyKg: 0.5)
        let gain = WeightGoal(
            userId: "user-1",
            objective: .gainWeight,
            startingWeightKg: 70,
            targetWeightKg: 76,
            weeklyChangeKg: 0.3
        )
        let maintain = WeightGoal(
            userId: "user-1",
            objective: .maintain,
            startingWeightKg: 72,
            targetWeightKg: 72,
            weeklyChangeKg: 0
        )

        #expect(loss.signedWeeklyChangeKg == -0.5)
        #expect(gain.signedWeeklyChangeKg == 0.3)
        #expect(maintain.signedWeeklyChangeKg == 0)
    }
}
