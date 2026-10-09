//
//  OnboardingWeightRatePresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// Step 3 of goal setting: a slider whose range is a share of body weight — 0.25% (losing) or 0.1%
/// (gaining) up to 1% a week, never above 1.5 kg — and the sentences that tell the user what that
/// means: a weekly figure, a monthly one, a calorie target, a finish date and how the target moves.
///
/// Only losing and gaining reach this screen; maintaining goes straight to the summary. Every line
/// here divides by something the user chose, which is where this app has already had a crash.
@MainActor
struct OnboardingWeightRatePresenterTests {

    private func rateUser(
        weightKg: Double? = 80,
        heightCm: Double? = nil,
        weightUnit: WeightUnitPreference? = .kilograms
    ) -> UserModel {
        UserModel(
            userId: "user-1",
            submittedHeightCentimeters: heightCm,
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

    /// Losing opens at 0.5% of body weight a week for a lean person (0.4 kg at 80 kg) and gaining
    /// at 0.25% (0.2 kg) — gaining faster than that is mostly fat, so the default is the
    /// recommendation (Helms 2014; Iraki 2019).
    @Test("The default rate depends on the objective")
    func testTheDefaultRateDependsOnTheObjective() {
        let losing = makeScreen()
        losing.presenter.onAppear(delegate: delegate(.loseWeight))
        #expect(abs(losing.presenter.weightChangeRate - 0.4) < 0.0001)
        #expect(losing.presenter.didInitialize)

        let gaining = makeScreen()
        gaining.presenter.onAppear(delegate: delegate(.gainWeight, target: 90))
        #expect(abs(gaining.presenter.weightChangeRate - 0.2) < 0.0001)
    }

    /// Someone with a BMI of 25 or more opens at 0.75% a week, and is not warned below 1%: in
    /// obesity, faster loss did not lead to more regain (Purcell 2014).
    @Test("A heavier person opens at three quarters of a percent")
    func testAHeavierPersonOpensAtThreeQuartersOfAPercent() {
        // 100 kg at 1.80 m is a BMI of 30.9.
        let screen = makeScreen(user: rateUser(weightKg: 100, heightCm: 180))
        screen.presenter.onAppear(delegate: delegate(.loseWeight, target: 85))

        #expect(abs(screen.presenter.weightChangeRate - 0.75) < 0.0001)
        #expect(screen.presenter.isLean == false)

        screen.presenter.weightChangeRate = 1.0
        #expect(screen.presenter.currentRateCategory != .aggressive)
        #expect(screen.presenter.rateWarningText(delegate: delegate(.loseWeight, target: 85)) == nil)
    }

    /// The slowest rates are a share of body weight too: 0.25% a week losing, 0.1% gaining.
    @Test("The minimum rate is a share of body weight")
    func testTheMinimumRateIsAShareOfBodyWeight() {
        let losing = makeScreen()
        losing.presenter.onAppear(delegate: delegate(.loseWeight))
        #expect(abs(losing.presenter.minWeightChangeRate - 0.2) < 0.0001)

        let gaining = makeScreen()
        gaining.presenter.onAppear(delegate: delegate(.gainWeight, target: 90))
        // 0.08 kg, snapped up to the slider's 0.05 kg step.
        #expect(abs(gaining.presenter.minWeightChangeRate - 0.1) < 0.0001)
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
    /// The thresholds are shares of body weight: under 0.5% a week is conservative, and above
    /// 0.75% is aggressive for a lean person losing — at 80 kg, 0.4 and 0.6 kg.
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

        // 0.5% of 50 kg; the old fixed 0.5 kg default would have been 1% of their weight.
        #expect(abs(screen.presenter.weightChangeRate - 0.25) < 0.0001)
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

    /// The calorie change comes from `EnergyDensity`: 7,700 kcal per kilogram, so half a kilogram a
    /// week is 550 kcal a day (it used to be a separate 3,500 kcal per pound). Off 2,600 kcal of
    /// expenditure that is 2,050.
    @Test("The calorie estimate uses the energy in a kilogram")
    func testTheCalorieEstimateUsesTheEnergyInAKilogram() {
        let screen = makeScreen()
        screen.interactor.expenditure = 2600
        screen.presenter.onAppear(delegate: delegate())
        screen.presenter.weightChangeRate = 0.5

        #expect(
            screen.presenter.estimatedCalorieTargetText(delegate: delegate())
                == "~ 2050 kcal estimated daily calorie target"
        )
        #expect(screen.presenter.deficitCapText(delegate: delegate()) == nil)
    }

    /// The same rate in the other direction is a surplus, not a deficit, and a surplus is not capped.
    @Test("Gaining adds the same calories losing would subtract")
    func testGainingAddsTheSameCaloriesLosingWouldSubtract() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate(.gainWeight, target: 90))
        screen.presenter.weightChangeRate = 0.5

        #expect(
            screen.presenter.estimatedCalorieTargetText(delegate: delegate(.gainWeight, target: 90))
                == "~ 2550 kcal estimated daily calorie target"
        )
    }

    /// A deficit is capped at a quarter of expenditure, as the plan caps it. 550 kcal off 2,000 is
    /// more than 500, so the target reads 1,500 and the screen says the rate is capped.
    @Test("A deficit over a quarter of expenditure is capped and said so")
    func testADeficitOverAQuarterIsCapped() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate())
        screen.presenter.weightChangeRate = 0.5

        #expect(
            screen.presenter.estimatedCalorieTargetText(delegate: delegate())
                == "~ 1500 kcal estimated daily calorie target"
        )
        #expect(screen.presenter.deficitCapText(delegate: delegate()) != nil)
    }

    /// The floor still holds beneath the cap: 1,500 kcal of expenditure less a quarter is 1,125,
    /// under the 1,350 floor for someone who has not given their sex.
    @Test("The calorie estimate never reads below the calorie floor")
    func testTheCalorieEstimateNeverReadsBelowTheCalorieFloor() {
        let screen = makeScreen()
        screen.interactor.expenditure = 1500
        screen.presenter.onAppear(delegate: delegate())
        screen.presenter.weightChangeRate = 0.8

        #expect(
            screen.presenter.estimatedCalorieTargetText(delegate: delegate())
                == "~ 1350 kcal estimated daily calorie target"
        )
    }

    /// Holding the rate means the target falls as weight does, about 24 kcal a day per kilogram
    /// (Hall 2011): ten kilograms to go is about 240 kcal a day lower by the goal.
    @Test("The screen says the target steps down as you lose")
    func testTheScreenSaysTheTargetStepsDown() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: delegate(.loseWeight, target: 70))

        let text = screen.presenter.targetStepText(delegate: delegate(.loseWeight, target: 70))
        #expect(text?.contains("240") == true)
        #expect(screen.presenter.targetStepText(delegate: delegate(.maintain, target: 80)) == nil)
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
