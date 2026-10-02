//
//  OnboardingGoalSummaryEstimateTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The goal summary estimates how long the goal will take by dividing the weight still to change
/// by the weekly rate. "Maintain" arrives here with neither: the target is the current weight and
/// the rate is zero, so the division is 0 / 0.
@MainActor
struct OnboardingGoalSummaryEstimateTests {

    private final class Interactor: SpyGlobalInteractor, GoalSummaryInteractor {
        var currentUser: UserModel?
        init(currentWeightKg: Double?) {
            self.currentUser = UserModel(userId: "u1", submittedWeightKilograms: currentWeightKg)
        }
        func saveGoal(_ goal: WeightGoal) async throws { }
        func updateCurrentGoalId(goalId: String?) async throws { }
    }

    private final class Router: GoalSummaryRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showCompleteAccountSetupView() { }
        func showHealthDisclaimerView() { }
        func showGoalSettingView() { }
        func showCustomisingDietProgramView() { }
        func showOnboardingCompletedView() { }
        func showDevSettingsView() { }
        func showCreateGymProfileView(delegate: CreateGymProfileDelegate) { }
        func showOnboardingMesocycleView(delegate: CreateMesocycleDelegate) { }
    }

    private func presenter(currentWeightKg: Double? = 80) -> GoalSummaryPresenter {
        GoalSummaryPresenter(interactor: Interactor(currentWeightKg: currentWeightKg), router: Router())
    }

    /// The crash this guards: `Int(Double.nan)` traps, and it ran while the screen was drawing, so
    /// choosing the most common objective took the app down rather than showing anything.
    @Test("Maintaining weight estimates zero weeks instead of trapping on NaN")
    func testMaintainingWeightEstimatesNoJourney() {
        let sut = presenter(currentWeightKg: 80)
        let delegate = GoalSummaryDelegate(
            overarchingObjective: .maintain,
            targetWeight: 80,
            weightChangeRate: 0
        )

        #expect(sut.estimatedWeeks(delegate: delegate) == 0)
        #expect(sut.estimatedMonths(delegate: delegate) == 0)
    }

    @Test("A real target with a zero rate is infinite, and reports zero rather than trapping")
    func testAZeroRateTowardsADifferentTargetDoesNotTrap() {
        let sut = presenter(currentWeightKg: 80)
        let delegate = GoalSummaryDelegate(
            overarchingObjective: .loseWeight,
            targetWeight: 70,
            weightChangeRate: 0
        )

        #expect(sut.estimatedWeeks(delegate: delegate) == 0)
        #expect(sut.estimatedMonths(delegate: delegate) == 0)
    }

    @Test("Losing ten kilos at half a kilo a week is twenty weeks")
    func testAnOrdinaryLossIsStillEstimatedNormally() {
        let sut = presenter(currentWeightKg: 80)
        let delegate = GoalSummaryDelegate(
            overarchingObjective: .loseWeight,
            targetWeight: 70,
            weightChangeRate: 0.5
        )

        #expect(sut.estimatedWeeks(delegate: delegate) == 20)
        #expect(sut.estimatedMonths(delegate: delegate) == 5)
    }

    @Test("Gaining counts the distance the same way losing does")
    func testGainingIsEstimatedFromTheAbsoluteDifference() {
        let sut = presenter(currentWeightKg: 70)
        let delegate = GoalSummaryDelegate(
            overarchingObjective: .gainWeight,
            targetWeight: 75,
            weightChangeRate: 0.25
        )

        #expect(sut.estimatedWeeks(delegate: delegate) == 20)
    }

    /// Without a stored weight there is no distance to cover, so the estimate is zero rather than
    /// a number derived from a missing starting point.
    @Test("An unknown current weight estimates zero rather than trapping")
    func testAMissingCurrentWeightEstimatesNoJourney() {
        let sut = presenter(currentWeightKg: nil)
        let delegate = GoalSummaryDelegate(
            overarchingObjective: .loseWeight,
            targetWeight: 70,
            weightChangeRate: 0.5
        )

        #expect(sut.estimatedWeeks(delegate: delegate) == 0)
    }
}
