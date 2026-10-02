//
//  OnboardingWeightRatePresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// Step 3 of goal setting: a slider between a quarter and one and a half kilograms a week, and the
/// four sentences that tell the user what that means — a weekly figure, a monthly one, a calorie
/// target and a finish date.
///
/// Only losing and gaining reach this screen; maintaining goes straight to the summary. Every line
/// here divides by something the user chose, which is where this app has already had a crash.
@MainActor
struct OnboardingWeightRatePresenterTests {

    private func rateUser(
        weightKg: Double? = 80,
        weightUnit: WeightUnitPreference? = .kilograms
    ) -> UserModel {
        UserModel(
            userId: "user-1",
            submittedWeightKilograms: weightKg,
            submittedWeightUnitPreference: weightUnit
        )
    }

    private final class Interactor: SpyGlobalInteractor, WeightRateInteractor {
        var currentUser: UserModel?
        var currentWeightKilograms: Double? { currentUser?.submittedWeightKilograms }
        var expenditure: Double = 2000

        init(currentUser: UserModel?) {
            self.currentUser = currentUser
        }

        func estimateTDEE(user: UserModel?) -> Double { expenditure }
    }

    private final class Router: WeightRateRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var summaryDelegates: [GoalSummaryDelegate] = []

        func showGoalSummaryView(delegate: GoalSummaryDelegate) { summaryDelegates.append(delegate) }
        func showDevSettingsView() { }
    }

    private struct Screen {
        let presenter: WeightRatePresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(user: UserModel? = nil) -> Screen {
        let interactor = Interactor(currentUser: user ?? rateUser())
        let router = Router()
        return Screen(
            presenter: WeightRatePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func delegate(
        _ objective: OverarchingObjective = .loseWeight,
        target: Double = 70
    ) -> WeightRateDelegate {
        WeightRateDelegate(delegate: TargetWeightDelegate(overarchingObjective: objective), targetWeight: target)
    }

    // MARK: - Opening state

    /// Losing opens at half a kilo a week and gaining at a quarter — gaining faster than that is
    /// mostly fat, so the default is the recommendation.
    @Test("The default rate depends on the objective")
    func testTheDefaultRateDependsOnTheObjective() {
        let losing = makeScreen()
        losing.presenter.onAppear(delegate: delegate(.loseWeight))
        #expect(losing.presenter.weightChangeRate == 0.5)
        #expect(losing.presenter.didInitialize)

        let gaining = makeScreen()
        gaining.presenter.onAppear(delegate: delegate(.gainWeight, target: 90))
        #expect(gaining.presenter.weightChangeRate == 0.25)
    }

    /// Everything on this screen is a share of the user's weight, so a profile without one falls
    /// back to a figure rather than dividing by nothing.
    @Test("A profile with no weight falls back rather than dividing by nothing")
    func testAMissingWeightFallsBack() {
        let screen = makeScreen(user: rateUser(weightKg: nil, weightUnit: nil))

        screen.presenter.onAppear(delegate: delegate())

        #expect(screen.presenter.currentWeight == 70)
        #expect(screen.presenter.weightUnit == .kilograms)
    }

    /// The category label under the slider is what tells a user their chosen rate is aggressive.
    /// The thresholds were
    /// fixed at 0.4 and 0.8 kg; they are now half and four-fifths of the person's own maximum,
    /// which at 80 kg is 0.8 kg a week, so 0.4 and 0.64.
    @Test("The rate category changes at its thresholds")
    func testTheRateCategoryChangesAtItsThresholds() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate())

        screen.presenter.weightChangeRate = 0.25
        #expect(screen.presenter.currentRateCategory == .conservative)

        screen.presenter.weightChangeRate = 0.35
        #expect(screen.presenter.currentRateCategory == .conservative)

        screen.presenter.weightChangeRate = 0.5
        #expect(screen.presenter.currentRateCategory == .standard)
        #expect(screen.presenter.rateWarningText(delegate: delegate()) == nil)

        screen.presenter.weightChangeRate = 0.65
        #expect(screen.presenter.currentRateCategory == .aggressive)
        #expect(screen.presenter.rateWarningText(delegate: delegate()) != nil)
        #expect(screen.presenter.rateWarningText(delegate: delegate(.gainWeight, target: 90)) != nil)

        screen.presenter.weightChangeRate = 0.8
        #expect(screen.presenter.currentRateCategory == .aggressive)
    }

    /// Decision 3: at most 1% of body weight a week, and never above the old 1.5 kg.
    @Test("The maximum rate is one percent of body weight, capped at 1.5 kg", arguments: [
        (80.0, 0.8), (60.0, 0.6), (30.0, 0.3), (150.0, 1.5), (220.0, 1.5), (73.0, 0.7)
    ])
    func testTheMaximumRateIsOnePercentOfBodyWeight(weightKg: Double, expected: Double) {
        let screen = makeScreen(user: rateUser(weightKg: weightKg))
        screen.presenter.onAppear(delegate: delegate())

        #expect(abs(screen.presenter.maxWeightChangeRate - expected) < 0.0001)
        // The default opens below the warning band, however light the person.
        #expect(screen.presenter.weightChangeRate <= screen.presenter.maxWeightChangeRate)
    }

    @Test("A light person's default rate opens below the warning")
    func testALightPersonsDefaultOpensBelowTheWarning() {
        let screen = makeScreen(user: rateUser(weightKg: 50))
        screen.presenter.onAppear(delegate: delegate(.loseWeight, target: 45))

        // The maximum is 0.5 kg; the old 0.5 default would open on the warning.
        #expect(abs(screen.presenter.weightChangeRate - 0.35) < 0.0001)
        #expect(screen.presenter.rateWarningText(delegate: delegate(.loseWeight, target: 45)) == nil)
    }

    // MARK: - What the rate reads as

    /// Losing reads as a minus and gaining as a plus. Inverting this is the one error on the screen
    /// a user would read as a reassurance rather than a mistake.
    @Test("Losing reads as minus and gaining as plus")
    func testLosingReadsAsMinusAndGainingAsPlus() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate(.loseWeight))
        screen.presenter.weightChangeRate = 0.5

        #expect(screen.presenter.weeklyWeightChangeText(delegate: delegate(.loseWeight)).hasPrefix("-0.50 kg"))
        #expect(screen.presenter.weeklyWeightChangeText(delegate: delegate(.gainWeight)).hasPrefix("+0.50 kg"))
    }

    /// The weekly figure is shown in the user's own unit: half a kilogram is 1.10 lb.
    @Test("The weekly figure is shown in the user's unit")
    func testTheWeeklyFigureIsShownInTheUsersUnit() {
        let screen = makeScreen(user: rateUser(weightUnit: .pounds))
        screen.presenter.onAppear(delegate: delegate())
        screen.presenter.weightChangeRate = 0.5

        #expect(screen.presenter.weeklyWeightChangeText(delegate: delegate()).contains("1.10 lb"))
    }

    /// Percent of body weight is the honest way to read a rate, and it is relative to the user's
    /// own weight: 0.5 kg of 75 kg is 0.7%.
    @Test("The weekly figure is also given as a share of body weight")
    func testTheWeeklyFigureIsAlsoGivenAsAShareOfBodyWeight() {
        let screen = makeScreen(user: rateUser(weightKg: 75))
        screen.presenter.onAppear(delegate: delegate())
        screen.presenter.weightChangeRate = 0.5

        #expect(screen.presenter.weeklyWeightChangeText(delegate: delegate()).contains("(0.7% of body weight)"))
    }

    /// The monthly line is four weeks of the weekly one, not a separately guessed number.
    @Test("The monthly figure is four weeks of the weekly one")
    func testTheMonthlyFigureIsFourWeeksOfTheWeeklyOne() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate())
        screen.presenter.weightChangeRate = 0.5

        #expect(screen.presenter.monthlyWeightChangeText(delegate: delegate()).hasPrefix("-2.00 kg"))
        #expect(screen.presenter.monthlyWeightChangeText(delegate: delegate()).contains("(2.5% of body weight)"))
    }

    /// The 3500 kcal rule is per pound. Half a kilogram a week is 1.10 lb, which is 3858 kcal a
    /// week or 551 a day off the 2000 kcal this suite's interactor reports as expenditure. Reading the rule as per kilogram would show 1750 —
    /// a deficit half as large again.
    @Test("The calorie estimate applies the 3500 rule per pound, not per kilogram")
    func testTheCalorieEstimateAppliesTheRulePerPound() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate())
        screen.presenter.weightChangeRate = 0.5

        #expect(
            screen.presenter.estimatedCalorieTargetText(delegate: delegate())
                == "~ 1448 kcal estimated daily calorie target"
        )
    }

    /// The same rate in the other direction is a surplus, not a deficit.
    @Test("Gaining adds the same calories losing would subtract")
    func testGainingAddsTheSameCaloriesLosingWouldSubtract() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate(.gainWeight, target: 90))
        screen.presenter.weightChangeRate = 0.5

        #expect(
            screen.presenter.estimatedCalorieTargetText(delegate: delegate(.gainWeight, target: 90))
                == "~ 2551 kcal estimated daily calorie target"
        )
    }

    /// The baseline was a fixed 2000 kcal, so someone who burns 2600 was shown a target 600 too low.
    @Test("The calorie estimate starts from the person's own expenditure")
    func testTheCalorieEstimateStartsFromThePersonsOwnExpenditure() {
        let screen = makeScreen()
        screen.interactor.expenditure = 2600
        screen.presenter.onAppear(delegate: delegate())
        screen.presenter.weightChangeRate = 0.5

        #expect(
            screen.presenter.estimatedCalorieTargetText(delegate: delegate())
                == "~ 2048 kcal estimated daily calorie target"
        )
    }

    /// At 1.5 kg a week the deficit is 1653 kcal a day. Off 2000 that read "~ 346 kcal". The
    /// slider no longer reaches 1.5 kg for this 80 kg user, but the floor still has to hold for a
    /// rate the presenter is handed.
    @Test("The calorie estimate never reads below the calorie floor")
    func testTheCalorieEstimateNeverReadsBelowTheCalorieFloor() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate())
        screen.presenter.weightChangeRate = 1.5

        #expect(
            screen.presenter.estimatedCalorieTargetText(delegate: delegate())
                == "~ 1200 kcal estimated daily calorie target"
        )
    }

    /// The calorie line is the same whichever unit the user reads in — the rule is arithmetic on
    /// the stored kilograms, not a presentation choice.
    @Test("The calorie estimate does not change with the display unit")
    func testTheCalorieEstimateIsUnitIndependent() {
        let metric = makeScreen()
        metric.presenter.onAppear(delegate: delegate())
        metric.presenter.weightChangeRate = 0.5

        let imperial = makeScreen(user: rateUser(weightUnit: .pounds))
        imperial.presenter.onAppear(delegate: delegate())
        imperial.presenter.weightChangeRate = 0.5

        #expect(
            metric.presenter.estimatedCalorieTargetText(delegate: delegate())
                == imperial.presenter.estimatedCalorieTargetText(delegate: delegate())
        )
    }

    // MARK: - When it finishes

    /// Ten kilograms at half a kilogram a week is twenty weeks.
    @Test("The end date is the distance divided by the rate")
    func testTheEndDateIsTheDistanceDividedByTheRate() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate(.loseWeight, target: 70))
        screen.presenter.weightChangeRate = 0.5

        #expect(
            screen.presenter.estimatedEndDateText(delegate: delegate(.loseWeight, target: 70))
                == endDateText(weeks: 20)
        )
    }

    /// Gaining ten kilograms takes as long as losing them; `abs` is what keeps the date in the
    /// future rather than in the past.
    @Test("Gaining gives a date in the future too")
    func testGainingGivesADateInTheFutureToo() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate(.gainWeight, target: 90))
        screen.presenter.weightChangeRate = 0.5

        #expect(
            screen.presenter.estimatedEndDateText(delegate: delegate(.gainWeight, target: 90))
                == endDateText(weeks: 20)
        )
    }

    /// The formatter the presenter uses, rebuilt here so the expectation is the date rather than a
    /// copy of the presenter's own arithmetic.
    private func endDateText(weeks: Int) -> String {
        let date = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Approximate end date: \(formatter.string(from: date))"
    }

    // MARK: - Leaving the screen

    /// A rate of zero divides the distance by nothing — infinite, or NaN when the target is
    /// already the current weight — and `Int` traps on both. The line is drawn with the rest of
    /// the screen, so the trap would take the app down rather than show a wrong date.
    @Test("A zero rate says there is no end date rather than trapping")
    func testAZeroRateHasNoEndDateRatherThanTrapping() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate(.loseWeight, target: 70))
        screen.presenter.weightChangeRate = 0

        #expect(
            screen.presenter.estimatedEndDateText(delegate: delegate(.loseWeight, target: 70))
                == "No approximate end date at this rate"
        )
        // 0 / 0 is NaN rather than infinity, and traps the same way.
        #expect(
            screen.presenter.estimatedEndDateText(delegate: delegate(.maintain, target: 80))
                == "No approximate end date at this rate"
        )
    }

    /// A rate of zero is a goal that never finishes, so Continue is gated on it.
    @Test("A rate of zero cannot be continued with")
    func testARateOfZeroCannotBeContinuedWith() {
        let screen = makeScreen()

        screen.presenter.weightChangeRate = 0
        #expect(screen.presenter.canContinue == false)

        screen.presenter.weightChangeRate = screen.presenter.minWeightChangeRate
        #expect(screen.presenter.canContinue)
    }

    @Test("The rate, the target and the objective all reach the summary")
    func testTheRateTargetAndObjectiveAllReachTheSummary() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate(.loseWeight, target: 70))
        screen.presenter.weightChangeRate = 0.75

        screen.presenter.onContinuePressed(delegate: delegate(.loseWeight, target: 70))

        #expect(screen.router.summaryDelegates.map(\.weightChangeRate) == [0.75])
        #expect(screen.router.summaryDelegates.map(\.targetWeight) == [70])
        #expect(screen.router.summaryDelegates.map(\.overarchingObjective) == [.loseWeight])
        #expect(screen.interactor.trackedEventNames == ["Onboarding_WeightRate_Navigate"])
    }
}
