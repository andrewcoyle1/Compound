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

    private static let today = Date(timeIntervalSince1970: 1_750_000_000)

    private func estimate(
        kcal: Double,
        isProvisional: Bool = false,
        weeklyTrendChangeKg: Double? = nil,
        sdKcal: Double? = 100,
        recentIntakeKcal: Double? = nil
    ) -> ExpenditureEstimate {
        ExpenditureEstimate(
            day: Self.today,
            kcal: kcal,
            source: isProvisional ? .prior : .adaptive,
            isProvisional: isProvisional,
            trendWeightKg: 80,
            weeklyTrendChangeKg: weeklyTrendChangeKg,
            loggedDays: 24,
            weighInCount: 20,
            windowDays: 28,
            stepAdjustmentKcal: 0,
            sdKcal: sdKcal,
            recentIntakeKcal: recentIntakeKcal
        )
    }

    private func plan(targetKcal: Double, floor: CalorieFloor = .standard, createdDaysAgo: Int = 30) -> DietPlan {
        DietPlan(
            planId: "plan-1",
            userId: "user-1",
            createdAt: Self.today.addingTimeInterval(-Double(createdDaysAgo) * 86_400),
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

    private func settings(mode: ExpenditureCalculationMode = .dynamic) -> NutritionStrategySettings {
        var settings = NutritionStrategySettings(authorId: "user-1")
        settings.calculationMode = mode
        return settings
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func make(
        _ estimate: ExpenditureEstimate,
        plan: DietPlan?,
        goal: WeightGoal? = nil,
        settings: NutritionStrategySettings? = nil,
        dismissedKcal: Double? = nil,
        kcalPerKg: Double = EnergyDensity.conventionalKcalPerKg,
        gender: Gender? = nil
    ) -> TargetProposal? {
        TargetProposal.make(
            estimate: estimate,
            plan: plan,
            goal: goal,
            settings: settings ?? self.settings(),
            dismissedKcal: dismissedKcal,
            kcalPerKg: kcalPerKg,
            gender: gender,
            calendar: utc
        )
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

    /// Feedforward: the target is the estimate plus the goal rate's daily share of the energy in a
    /// kilogram, reached in steps of at most 150 kcal a week.
    @Test("Test With No Active Goal The Proposal Steps Towards Maintenance")
    func testWithNoActiveGoalTheProposalStepsTowardsMaintenance() throws {
        let proposal = try #require(make(estimate(kcal: 2800), plan: plan(targetKcal: 2000)))

        #expect(proposal.proposedTargetKcal == 2000 + TargetProposal.maximumStepKcal)
        #expect(proposal.expenditureKcal == 2800)
        #expect(proposal.currentTargetKcal == 2000)
        #expect(proposal.goalWeeklyChangeKg == nil)
        #expect(proposal.reason == .expenditureMoved)
    }

    @Test("Test A Move Inside The Step Limit Lands On The Target")
    func testAMoveInsideTheStepLimitLandsOnTheTarget() throws {
        let proposal = try #require(make(estimate(kcal: 2120), plan: plan(targetKcal: 2000)))

        #expect(proposal.proposedTargetKcal == 2120)
    }

    @Test("Test A Paused Goal Does Not Count As A Goal")
    func testAPausedGoalDoesNotCountAsAGoal() throws {
        let proposal = try #require(make(estimate(kcal: 2120), plan: plan(targetKcal: 2000), goal: lossGoal(status: .paused)))

        #expect(proposal.proposedTargetKcal == 2120)
        #expect(proposal.goalWeeklyChangeKg == nil)
    }

    @Test("Test A Half Kilo A Week Loss Goal Takes Five Hundred And Fifty Off")
    func testAHalfKiloAWeekLossGoalTakesFiveHundredAndFiftyOff() throws {
        // 2,800 − 0.5 · 7,700 / 7 = 2,250: inside the step limit from 2,140.
        let proposal = try #require(make(estimate(kcal: 2800), plan: plan(targetKcal: 2140), goal: lossGoal()))

        #expect(proposal.proposedTargetKcal == 2250)
        #expect(proposal.goalWeeklyChangeKg == -0.5)
    }

    @Test("Test A Leaner Energy Density Takes Less Off For The Same Rate")
    func testALeanerEnergyDensityTakesLessOffForTheSameRate() throws {
        // 6,300 kcal/kg: 2,800 − 0.5 · 6,300 / 7 = 2,350.
        let proposal = try #require(
            make(estimate(kcal: 2800), plan: plan(targetKcal: 2240), goal: lossGoal(), kcalPerKg: 6300)
        )

        #expect(proposal.proposedTargetKcal == 2350)
    }

    // MARK: - No double counting

    /// The old controller added (goal rate − observed rate) · 7700 / 7 on top. The filter already
    /// absorbs that gap, so the observed rate no longer changes what is proposed.
    @Test("Test The Observed Rate Does Not Add A Second Correction")
    func testTheObservedRateDoesNotAddASecondCorrection() throws {
        let onPace = try #require(
            make(estimate(kcal: 2800, weeklyTrendChangeKg: -0.5), plan: plan(targetKcal: 2140), goal: lossGoal())
        )
        let behind = try #require(
            make(estimate(kcal: 2800, weeklyTrendChangeKg: -0.2), plan: plan(targetKcal: 2140), goal: lossGoal())
        )

        #expect(onPace.proposedTargetKcal == 2250)
        #expect(behind.proposedTargetKcal == 2250)
    }

    // MARK: - The deadband and cadence

    @Test("Test The Deadband Grows With The Estimate's Uncertainty")
    func testTheDeadbandGrowsWithTheEstimatesUncertainty() {
        // 120 kcal apart: past the 50 kcal floor, but inside a 150 kcal SD.
        #expect(make(estimate(kcal: 2120, sdKcal: 100), plan: plan(targetKcal: 2000)) != nil)
        #expect(make(estimate(kcal: 2120, sdKcal: 150), plan: plan(targetKcal: 2000)) == nil)
    }

    @Test("Test No Proposal Within A Week Of The Last Change")
    func testNoProposalWithinAWeekOfTheLastChange() {
        #expect(make(estimate(kcal: 2200), plan: plan(targetKcal: 2000, createdDaysAgo: 6)) == nil)
        #expect(make(estimate(kcal: 2200), plan: plan(targetKcal: 2000, createdDaysAgo: 7)) != nil)
    }

    // MARK: - Adherence before lowering

    /// Eating well over the target and losing slower than planned: lowering the target would chase
    /// the eating, so the check-in talks about adherence instead.
    @Test("Test Eating Over The Target Gets A Note Not A Lower Target")
    func testEatingOverTheTargetGetsANoteNotALowerTarget() throws {
        let overEating = estimate(kcal: 2500, weeklyTrendChangeKg: -0.1, recentIntakeKcal: 2500)
        let current = plan(targetKcal: 2150)

        #expect(make(overEating, plan: current, goal: lossGoal()) == nil)
        let note = try #require(
            AdherenceNote.make(estimate: overEating, plan: current, goal: lossGoal(), settings: settings(), calendar: utc)
        )
        #expect(note.targetKcal == 2150)
        #expect(note.recentIntakeKcal == 2500)
    }

    @Test("Test Eating On Target Still Lets The Target Come Down")
    func testEatingOnTargetStillLetsTheTargetComeDown() throws {
        let onTarget = estimate(kcal: 2500, weeklyTrendChangeKg: -0.1, recentIntakeKcal: 2200)
        let proposal = try #require(make(onTarget, plan: plan(targetKcal: 2150), goal: lossGoal()))

        #expect(proposal.proposedTargetKcal == 2000)
        #expect(AdherenceNote.make(estimate: onTarget, plan: plan(targetKcal: 2150), goal: lossGoal(), settings: settings(), calendar: utc) == nil)
    }

    // MARK: - The floor

    @Test("Test The Calorie Floor Holds The Proposal Up By Sex")
    func testTheCalorieFloorHoldsTheProposalUpBySex() throws {
        // 1,400 expenditure against a 1 kg/wk loss goal would propose 300 kcal a day.
        let steepGoal = WeightGoal(
            userId: "user-1",
            objective: .loseWeight,
            startingWeightKg: 85,
            targetWeightKg: 70,
            weeklyChangeKg: 1.0,
            status: .active
        )
        let floor = CalorieFloor.standard.minimumValue(for: .male)
        let proposal = try #require(
            make(estimate(kcal: 1400), plan: plan(targetKcal: floor + 140), goal: steepGoal, gender: .male)
        )

        #expect(proposal.proposedTargetKcal == floor)
    }

    // MARK: - Dismissal

    @Test("Test A Dismissed Figure Stays Dismissed")
    func testADismissedFigureStaysDismissed() {
        let proposal = TargetProposal.make(
            estimate: estimate(kcal: 2800),
            plan: plan(targetKcal: 2000),
            goal: nil,
            settings: settings(),
            dismissedKcal: 2140
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
                dismissedKcal: 2050
            )
        )

        #expect(proposal.proposedTargetKcal == 2150)
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
