//
//  NutritionGoalTargetTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The weight goal sets the calorie target. The plan used to be built at expenditure whatever the
/// goal said, so a goal to lose half a kilogram a week set no deficit until a check-in proposed
/// one — and none is proposed while the estimate is still provisional.
@MainActor
struct NutritionGoalTargetTests {

    private func goal(start: Double = 82, target: Double, rate: Double = 0.5, status: WeightGoal.GoalStatus = .active) -> WeightGoal {
        WeightGoal(
            userId: "u", objective: target < start ? .loseWeight : (target > start ? .gainWeight : .maintain),
            startingWeightKg: start, targetWeightKg: target, weeklyChangeKg: rate, status: status
        )
    }

    private func delegate(calorieFloor: CalorieFloor = .standard) -> DietPlanDelegate {
        DietPlanDelegate(
            oldDelegate: ProteinIntakeDelegate(
                delegate: CalorieDistributionDelegate(
                    delegate: CalorieFloorDelegate(preferredDiet: .balanced, isFromSettings: false),
                    calorieFloor: calorieFloor
                ),
                calorieDistribution: .even
            ),
            proteinIntake: .moderate
        )
    }

    private func averageCalories(_ plan: DietPlan) -> Double {
        plan.days.map(\.calories).reduce(0, +) / Double(plan.days.count)
    }

    /// 7,700 kcal per kg spread over the week: half a kilogram is 550 kcal a day.
    @Test("Test The Goal's Pace Is The Daily Difference From Expenditure")
    func testGoalTarget() {
        #expect(NutritionManager.goalTarget(expenditureKcal: 2_500, goal: goal(target: 75, rate: 0.5)) == 1_950)
        #expect(NutritionManager.goalTarget(expenditureKcal: 2_500, goal: goal(target: 90, rate: 0.25)) == 2_775)
        #expect(NutritionManager.goalTarget(expenditureKcal: 2_500, goal: goal(target: 82, rate: 0)) == 2_500)
        #expect(NutritionManager.goalTarget(expenditureKcal: 2_500, goal: nil) == 2_500)
        #expect(NutritionManager.goalTarget(expenditureKcal: 2_500, goal: goal(target: 75, status: .abandoned)) == 2_500)
    }

    /// A deficit is capped at a quarter of expenditure, so the fastest rate on a small expenditure
    /// cannot ask for a crash diet. A kilogram a week is 1,100 kcal a day; a quarter of 1,800 is 450.
    /// A surplus is not capped.
    @Test("Test A Deficit Is Capped At A Quarter Of Expenditure")
    func testDeficitCap() {
        #expect(NutritionManager.goalTarget(expenditureKcal: 1_800, goal: goal(target: 70, rate: 1)) == 1_350)
        #expect(NutritionManager.goalTarget(expenditureKcal: 1_800, goal: goal(target: 95, rate: 1)) == 2_900)
    }

    @Test("Test A Plan Built With A Goal Eats To Its Pace")
    func testPlanUsesGoal() {
        let manager = TestManagers.nutritionManager()

        let plan = manager.computeDietPlan(user: nil, delegate: delegate(), expenditureKcal: 2_500, goal: goal(target: 75))

        #expect(abs(averageCalories(plan) - 1_950) < 1)
        // Expenditure is recorded as it was, not the target, for the next check-in to compare.
        #expect(plan.tdeeEstimate == 2_500)
    }

    /// The floor holds whatever the goal asks for.
    @Test("Test The Calorie Floor Holds Against An Aggressive Goal")
    func testFloorHolds() {
        let manager = TestManagers.nutritionManager()

        let plan = manager.computeDietPlan(user: nil, delegate: delegate(), expenditureKcal: 1_500, goal: goal(target: 60, rate: 1))

        #expect(averageCalories(plan) >= CalorieFloor.standard.minimumValue - 1)
    }

    /// An explicit target, as a check-in's accepted proposal passes, is used as given.
    @Test("Test An Explicit Target Wins Over The Goal")
    func testExplicitTarget() {
        let manager = TestManagers.nutritionManager()

        let plan = manager.computeDietPlan(user: nil, delegate: delegate(), expenditureKcal: 2_500, targetKcal: 2_200, goal: goal(target: 75))

        #expect(abs(averageCalories(plan) - 2_200) < 1)
    }
}
