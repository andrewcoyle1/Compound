//
//  OnboardingGoalSettingPresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

// Setting the goal: lose, maintain or gain; a target weight; a weekly rate; and a summary that
// turns the three into a date and saves the goal.
//
// The arithmetic here is small but signed. A target below the current weight is a loss and a
// target above it is a gain, and every downstream calorie target reads the sign off this goal —
// so a target on the wrong side of the objective would quietly tell a user to eat their way to a
// weight they were trying to leave.

/// The signed-in user as the goal screens see them: a weight, and the unit it should be shown in.
@MainActor
private func goalUser(
    weightKg: Double? = 80,
    weightUnit: WeightUnitPreference? = .kilograms
) -> UserModel {
    UserModel(
        userId: "user-1",
        submittedDateOfBirth: Calendar.current.date(from: DateComponents(year: 1988, month: 3, day: 14)),
        submittedGender: .male,
        submittedHeightCentimeters: 180,
        submittedWeightKilograms: weightKg,
        submittedExerciseFrequency: .threeToFour,
        submittedDailyActivityLevel: .moderate,
        submittedCardioFitnessLevel: .intermediate,
        submittedWeightUnitPreference: weightUnit,
        acceptedHealthDisclaimerVersion: UserModel.currentHealthDisclaimerVersion
    )
}

// MARK: - The splash that starts goal setting

@MainActor
struct OnboardingGoalSettingPresenterTests {

    private final class Interactor: SpyGlobalInteractor, GoalSettingInteractor {
        var currentUser: UserModel?
    }

    private final class Router: GoalSettingRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showOverarchingObjectiveView() { shown.append("objective") }
        func showDevSettingsView() { shown.append("devSettings") }
    }

    @Test("Starting goal setting opens the objective step")
    func testStartingGoalSettingOpensTheObjectiveStep() {
        let interactor = Interactor()
        let router = Router()
        let sut = GoalSettingPresenter(interactor: interactor, router: router)

        sut.onContinuePressed()

        #expect(router.shown == ["objective"])
        #expect(interactor.trackedEventNames == ["GoalSetting_Navigate"])
    }
}

// MARK: - Step 1: lose, maintain or gain

/// The fork in the flow. Losing and gaining go on to pick a target and a rate; maintaining skips
/// both and goes straight to the summary with the current weight as its own target.
@MainActor
struct OnboardingObjectivePresenterTests {

    private final class Interactor: SpyGlobalInteractor, OverarchingObjectiveInteractor {
        var currentUser: UserModel?

        init(currentUser: UserModel? = nil) {
            self.currentUser = currentUser
        }
    }

    private final class Router: OverarchingObjectiveRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var targetWeightDelegates: [TargetWeightDelegate] = []
        private(set) var summaryDelegates: [GoalSummaryDelegate] = []

        func showTargetWeightView(delegate: TargetWeightDelegate) { targetWeightDelegates.append(delegate) }
        func showGoalSummaryView(delegate: GoalSummaryDelegate) { summaryDelegates.append(delegate) }
        func showDevSettingsView() { }
    }

    private struct Screen {
        let presenter: OverarchingObjectivePresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(user: UserModel? = nil) -> Screen {
        let interactor = Interactor(currentUser: user ?? goalUser())
        let router = Router()
        return Screen(
            presenter: OverarchingObjectivePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// The whole goal is expressed relative to the current weight, so without one there is nothing
    /// to set a target against.
    @Test("An objective without a current weight cannot be continued with")
    func testAnObjectiveNeedsACurrentWeightToBeUsable() {
        let screen = makeScreen(user: goalUser(weightKg: nil))
        screen.presenter.selectedObjective = .loseWeight

        #expect(screen.presenter.canContinue == false)

        screen.presenter.onContinuePressed()

        #expect(screen.router.targetWeightDelegates.isEmpty)
        #expect(screen.router.summaryDelegates.isEmpty)
        #expect(screen.interactor.trackedEventNames.isEmpty)
    }

    @Test("An objective must be chosen before continuing")
    func testAnObjectiveMustBeChosenBeforeContinuing() {
        let screen = makeScreen()

        #expect(screen.presenter.canContinue == false)

        screen.presenter.onContinuePressed()

        #expect(screen.router.targetWeightDelegates.isEmpty)
        #expect(screen.router.summaryDelegates.isEmpty)
    }

    @Test("Losing weight goes on to pick a target")
    func testLosingWeightGoesOnToPickATarget() {
        let screen = makeScreen()
        screen.presenter.selectedObjective = .loseWeight

        #expect(screen.presenter.canContinue)
        screen.presenter.onContinuePressed()

        #expect(screen.router.targetWeightDelegates.map(\.overarchingObjective) == [.loseWeight])
        #expect(screen.router.summaryDelegates.isEmpty)
        #expect(screen.interactor.trackedEventNames == ["OverarchingObjecting_Navigate"])
    }

    @Test("Gaining weight goes on to pick a target too")
    func testGainingWeightGoesOnToPickATargetToo() {
        let screen = makeScreen()
        screen.presenter.selectedObjective = .gainWeight

        screen.presenter.onContinuePressed()

        #expect(screen.router.targetWeightDelegates.map(\.overarchingObjective) == [.gainWeight])
        #expect(screen.router.summaryDelegates.isEmpty)
    }

    /// Maintaining has no target to pick and no rate to choose, so it skips two screens — and
    /// arrives at the summary with a rate of zero, which is the case the summary has to survive.
    @Test("Maintaining skips straight to the summary at the current weight")
    func testMaintainingSkipsStraightToTheSummaryAtTheCurrentWeight() {
        let screen = makeScreen(user: goalUser(weightKg: 72.5))
        screen.presenter.selectedObjective = .maintain

        screen.presenter.onContinuePressed()

        #expect(screen.router.targetWeightDelegates.isEmpty)
        #expect(screen.router.summaryDelegates.map(\.overarchingObjective) == [.maintain])
        #expect(screen.router.summaryDelegates.map(\.targetWeight) == [72.5])
        #expect(screen.router.summaryDelegates.map(\.weightChangeRate) == [0])
    }
}

// MARK: - Step 2: the target weight

/// A wheel of weights, bounded by the objective: a target above your weight is not a way to lose
/// it, and a target below it is not a way to gain.
@MainActor
struct OnboardingTargetWeightPresenterTests {

    private final class Interactor: SpyGlobalInteractor, TargetWeightInteractor {
        var currentUser: UserModel?

        init(currentUser: UserModel?) {
            self.currentUser = currentUser
        }
    }

    private final class Router: TargetWeightRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var rateDelegates: [WeightRateDelegate] = []

        func showWeightRateView(delegate: WeightRateDelegate) { rateDelegates.append(delegate) }
        func showDevSettingsView() { }
    }

    private struct Screen {
        let presenter: TargetWeightPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(user: UserModel? = nil) -> Screen {
        let interactor = Interactor(currentUser: user ?? goalUser())
        let router = Router()
        return Screen(
            presenter: TargetWeightPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// Someone losing weight cannot be offered a target above where they are now.
    @Test("Losing weight bounds the target below the current weight")
    func testLosingWeightBoundsTheTargetBelowTheCurrentWeight() {
        let screen = makeScreen()

        let range = screen.presenter.kilogramRange(delegate: TargetWeightDelegate(overarchingObjective: .loseWeight))

        // The bottom was a flat 30 kg for everybody. It is now a BMI of 18.5 for this user's
        // 180 cm (decision 3a): 18.5 x 1.8 x 1.8 = 59.94 kg, rounded up so no stop is below it.
        #expect(range.lowerBound == 60)
        #expect(range.upperBound == 80)
    }

    @Test("The pound wheel stops at the same BMI, rounded up")
    func testThePoundWheelStopsAtTheSameBMI() {
        let screen = makeScreen(user: goalUser(weightKg: 80, weightUnit: .pounds))

        let range = screen.presenter.poundRange(delegate: TargetWeightDelegate(overarchingObjective: .loseWeight))

        // 59.94 kg is 132.14 lb.
        #expect(range.lowerBound == 133)
    }

    @Test("Without a height the wheel keeps its old floor and gives no reason")
    func testWithoutAHeightTheWheelKeepsItsOldFloor() {
        let user = UserModel(userId: "user-1", submittedWeightKilograms: 80, submittedWeightUnitPreference: .kilograms)
        let screen = makeScreen(user: user)
        let delegate = TargetWeightDelegate(overarchingObjective: .loseWeight)

        #expect(screen.presenter.kilogramRange(delegate: delegate).lowerBound == 30)
        #expect(screen.presenter.lowestTargetMessage(delegate: delegate) == nil)
    }

    @Test("The screen says why the wheel stops, only when losing")
    func testTheScreenSaysWhyTheWheelStops() {
        let screen = makeScreen()
        screen.presenter.onAppear(delegate: TargetWeightDelegate(overarchingObjective: .loseWeight))

        let message = screen.presenter.lowestTargetMessage(delegate: TargetWeightDelegate(overarchingObjective: .loseWeight))
        #expect(message?.contains("60 kg") == true)
        #expect(screen.presenter.lowestTargetMessage(delegate: TargetWeightDelegate(overarchingObjective: .gainWeight)) == nil)
    }

    /// Someone already at or under the floor gets a one-stop wheel above their own weight. That is
    /// not a target to lose towards, so Continue stays off and the screen says why.
    @Test("A weight already under the floor offers no target to lose towards")
    func testAWeightUnderTheFloorOffersNoTarget() {
        let screen = makeScreen(user: goalUser(weightKg: 55))
        let delegate = TargetWeightDelegate(overarchingObjective: .loseWeight)
        screen.presenter.onAppear(delegate: delegate)

        #expect(screen.presenter.kilogramRange(delegate: delegate) == 60...60)
        #expect(screen.presenter.canContinue == false)
        #expect(screen.presenter.lowestTargetMessage(delegate: delegate)?.contains("already") == true)
    }

    /// And someone gaining cannot be offered one below it.
    @Test("Gaining weight bounds the target above the current weight")
    func testGainingWeightBoundsTheTargetAboveTheCurrentWeight() {
        let screen = makeScreen()

        let range = screen.presenter.kilogramRange(delegate: TargetWeightDelegate(overarchingObjective: .gainWeight))

        #expect(range.lowerBound == 80)
        #expect(range.upperBound == 200)
    }

    /// Maintaining offers a window either side rather than a direction.
    @Test("Maintaining offers a window on both sides of the current weight")
    func testMaintainingOffersAWindowOnBothSides() {
        let screen = makeScreen()

        let range = screen.presenter.kilogramRange(delegate: TargetWeightDelegate(overarchingObjective: .maintain))

        #expect(range.lowerBound == 70)
        #expect(range.upperBound == 90)
    }

    /// Almost nobody weighs a whole number of kilograms, and the wheel only offers whole ones. The
    /// bound facing the user's weight has to round away from the objective, or the closest target
    /// on offer is on the wrong side of it: at 72.6 kg, a "lose weight" wheel reaching 73 is a
    /// wheel whose nearest option is to gain.
    @Test("A fractional weight never puts the nearest target on the wrong side")
    func testAFractionalWeightIsRoundedAwayFromTheObjective() {
        let screen = makeScreen(user: goalUser(weightKg: 72.6))

        let losing = screen.presenter.kilogramRange(delegate: TargetWeightDelegate(overarchingObjective: .loseWeight))
        #expect(losing.upperBound == 72)

        let gaining = screen.presenter.kilogramRange(delegate: TargetWeightDelegate(overarchingObjective: .gainWeight))
        #expect(gaining.lowerBound == 73)
    }

    /// The pound wheel is where this bites hardest: converting kilograms leaves a fraction for
    /// nearly every stored weight. 80 kg is 176.37 lb, so the bounds are 176 and 177.
    @Test("The pound wheel is rounded away from the objective too")
    func testThePoundWheelIsRoundedAwayFromTheObjective() {
        let screen = makeScreen(user: goalUser(weightKg: 80, weightUnit: .pounds))

        let losing = screen.presenter.poundRange(delegate: TargetWeightDelegate(overarchingObjective: .loseWeight))
        #expect(losing.upperBound == 176)

        let gaining = screen.presenter.poundRange(delegate: TargetWeightDelegate(overarchingObjective: .gainWeight))
        #expect(gaining.lowerBound == 177)
    }

    /// Someone already past the top of the wheel still has to get a range rather than an inverted
    /// one, which `ClosedRange` traps on constructing.
    @Test("A weight beyond the top of the wheel still gives a valid range")
    func testAWeightBeyondTheWheelStillGivesAValidRange() {
        let screen = makeScreen(user: goalUser(weightKg: 230))

        for objective in OverarchingObjective.allCases {
            let kgRange = screen.presenter.kilogramRange(delegate: TargetWeightDelegate(overarchingObjective: objective))
            let lbRange = screen.presenter.poundRange(delegate: TargetWeightDelegate(overarchingObjective: objective))
            #expect(kgRange.lowerBound <= kgRange.upperBound)
            #expect(lbRange.lowerBound <= lbRange.upperBound)
        }
    }

    /// A profile with no weight still has to produce a usable wheel rather than an empty or
    /// inverted range, which `ClosedRange` traps on constructing.
    @Test("A missing current weight still gives a valid range in both units")
    func testAMissingCurrentWeightStillGivesAValidRange() {
        let screen = makeScreen(user: goalUser(weightKg: nil))

        for objective in OverarchingObjective.allCases {
            let kgRange = screen.presenter.kilogramRange(delegate: TargetWeightDelegate(overarchingObjective: objective))
            let lbRange = screen.presenter.poundRange(delegate: TargetWeightDelegate(overarchingObjective: objective))
            #expect(kgRange.lowerBound <= kgRange.upperBound)
            #expect(lbRange.lowerBound <= lbRange.upperBound)
        }
    }

    /// A stored weight that is not a number at all. Both wheels turn the weight into an `Int`,
    /// and `Int(_:)` traps on NaN and on either infinity — the `max(1, Int(weight))` in `onAppear`
    /// was no help, because the trap is inside the conversion and the floor never ran. Both ranges
    /// are read from the view body, so the screen would have gone down as it drew.
    @Test("A stored weight that is not a number still gives a valid wheel")
    func testAWeightThatIsNotANumberStillGivesAValidWheel() {
        for weight in [Double.nan, .infinity, -.infinity] {
            let screen = makeScreen(user: goalUser(weightKg: weight))

            for objective in OverarchingObjective.allCases {
                let delegate = TargetWeightDelegate(overarchingObjective: objective)
                let kgRange = screen.presenter.kilogramRange(delegate: delegate)
                let lbRange = screen.presenter.poundRange(delegate: delegate)
                #expect(kgRange.lowerBound <= kgRange.upperBound)
                #expect(lbRange.lowerBound <= lbRange.upperBound)
            }

            screen.presenter.onAppear(delegate: TargetWeightDelegate(overarchingObjective: .loseWeight))
            // Treated as a missing weight, which already fell back to 70 kg.
            #expect(screen.presenter.currentWeight == 70)
            #expect(screen.presenter.targetWeight.isFinite)
        }
    }

    /// The wheel opens on the user's own weight, so the first flick is a change they meant rather
    /// than a correction of a number the app invented.
    @Test("The wheel opens on the user's own weight")
    func testTheWheelOpensOnTheUsersOwnWeight() {
        let screen = makeScreen(user: goalUser(weightKg: 72))

        screen.presenter.onAppear(delegate: TargetWeightDelegate(overarchingObjective: .loseWeight))

        #expect(screen.presenter.currentWeight == 72)
        #expect(screen.presenter.selectedKilograms == 72)
        #expect(screen.presenter.didInitialize)
    }

    /// A pounds user must see pounds. Showing them a kilogram wheel is the same failure as showing
    /// exercise history in the wrong unit: the number is right and unreadable.
    @Test("A pounds user gets a pounds wheel around their weight")
    func testAPoundsUserGetsAPoundsWheelAroundTheirWeight() {
        let screen = makeScreen(user: goalUser(weightKg: 80, weightUnit: .pounds))

        screen.presenter.onAppear(delegate: TargetWeightDelegate(overarchingObjective: .loseWeight))

        #expect(screen.presenter.weightUnit == .pounds)
        // 80 kg is 176.4 lb, and the wheel is in whole pounds — so the kilogram figure it stores
        // is the round trip back from 176, not the 80 it started from.
        #expect(screen.presenter.selectedPounds == 176)
        #expect(abs(screen.presenter.targetWeight - UnitConversion.lbsToKg(176)) < 0.0001)
    }

    /// The two wheels describe one weight. Moving either has to leave the other agreeing, or the
    /// unit toggle would change the goal.
    @Test("The kilogram and pound wheels stay in step")
    func testTheTwoWheelsStayInStep() {
        let screen = makeScreen()

        screen.presenter.selectedKilograms = 70
        screen.presenter.updateFromKilograms()
        #expect(screen.presenter.targetWeight == 70)
        #expect(screen.presenter.selectedPounds == 154)

        screen.presenter.selectedPounds = 154
        screen.presenter.updateFromPounds()
        #expect(screen.presenter.selectedKilograms == 70)
    }

    /// A target equal to the current weight is not a change; letting it through would create a
    /// "lose weight" goal with nothing to lose and a finish date of today.
    @Test("A target equal to the current weight is not a goal")
    func testATargetEqualToTheCurrentWeightIsNotAGoal() {
        let screen = makeScreen(user: goalUser(weightKg: 80))
        screen.presenter.onAppear(delegate: TargetWeightDelegate(overarchingObjective: .loseWeight))

        #expect(screen.presenter.targetWeight == 80)
        #expect(screen.presenter.canContinue == false)

        screen.presenter.selectedKilograms = 75
        screen.presenter.updateFromKilograms()

        #expect(screen.presenter.canContinue)
    }

    @Test("The target and the objective travel together to the rate step")
    func testTheTargetAndTheObjectiveTravelToTheRateStep() {
        let screen = makeScreen()
        screen.presenter.selectedKilograms = 74
        screen.presenter.updateFromKilograms()

        screen.presenter.onContinuePressed(delegate: TargetWeightDelegate(overarchingObjective: .loseWeight))

        #expect(screen.router.rateDelegates.map(\.targetWeight) == [74])
        #expect(screen.router.rateDelegates.map(\.overarchingObjective) == [.loseWeight])
        #expect(screen.interactor.trackedEventNames == ["Onboarding_TargetWeight_Navigate"])
    }
}
