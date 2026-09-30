//
//  OnboardingDietChoicesPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

// The four questions the diet plan is built from: which diet, how low calories may go, whether
// the week is flat or varied, and how much protein.
//
// Each screen collects one answer and hands the accumulated answers to the next through a
// delegate. Nothing is stored along the way, so an answer dropped between two screens is an
// answer the finished plan was never built from — and the user has no way to tell.

// MARK: - The splash that starts the diet questions

@MainActor
struct OnboardingCustomisingDietTests {

    private final class Interactor: SpyGlobalInteractor, CustomisingDietProgramInteractor {
        var currentUser: UserModel?
    }

    private final class Router: CustomisingDietProgramRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []

        func showDevSettingsView() { shown.append("devSettings") }
        func showPreferredDietView() { shown.append("preferredDiet") }
    }

    @Test("Test Continuing Opens The First Diet Question")
    func testContinuingOpensTheFirstDietQuestion() {
        let interactor = Interactor()
        let router = Router()
        let presenter = CustomisingDietProgramPresenter(interactor: interactor, router: router)

        presenter.navigateToPreferredDiet()

        #expect(router.shown == ["preferredDiet"])
        #expect(interactor.trackedEventNames == ["Onboarding_CustProgram_Navigate"])
    }

}

// MARK: - Which diet

/// The diet decides how the non-protein calories are split between fat and carbs, so it has to
/// survive the four screens between being picked and the plan being built.
@MainActor
struct OnboardingPreferredDietPresenterTests {

    private final class Interactor: SpyGlobalInteractor, PreferredDietInteractor { }

    private final class Router: PreferredDietRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var delegates: [CalorieFloorDelegate] = []
        private(set) var distributionDelegates: [CalorieDistributionDelegate] = []

        func showDevSettingsView() { }
        func showCalorieFloorView(delegate: CalorieFloorDelegate) { delegates.append(delegate) }
        func showCalorieDistributionView(delegate: CalorieDistributionDelegate) { distributionDelegates.append(delegate) }
    }

    /// Nothing picked, nothing to carry — moving on would build a plan around a default the user
    /// never saw.
    @Test("Test No Diet Picked Does Not Move On")
    func testNoDietPickedDoesNotMoveOn() {
        let interactor = Interactor()
        let router = Router()
        let presenter = PreferredDietPresenter(interactor: interactor, router: router)

        presenter.navigateToCalorieFloor()

        #expect(router.delegates.isEmpty)
        #expect(router.distributionDelegates.isEmpty)
        // A navigation event logged without a navigation would read as a step the user completed.
        #expect(interactor.trackedEventNames.isEmpty)
    }

    /// Every one of the four diets has to reach the next screen unchanged — the plan builder
    /// branches on this value, and a diet that silently became `.balanced` would produce a plan
    /// that looks plausible and is not what was asked for.
    @Test("Test The Chosen Diet Is Carried To The Next Question", arguments: PreferredDiet.allCases)
    func testTheChosenDietIsCarriedToTheNextQuestion(diet: PreferredDiet) {
        let interactor = Interactor()
        let router = Router()
        let presenter = PreferredDietPresenter(interactor: interactor, router: router)
        presenter.selectedDiet = diet

        presenter.navigateToCalorieFloor()

        // In onboarding the next question is the calorie distribution: the floor step is skipped
        // (decision 3b), so the diet arrives there rather than at the floor screen.
        #expect(router.distributionDelegates.first?.preferredDiet == diet)
        #expect(interactor.trackedEventNames == ["Onboarding_PrefDiet_Navigate"])
    }

    /// Decision 3b: onboarding applies the standard 1,200 kcal floor and never shows the step
    /// that offers 800 kcal. It was the next screen for everybody.
    @Test("Test Onboarding Applies The Standard Floor Without Asking")
    func testOnboardingAppliesTheStandardFloorWithoutAsking() {
        let router = Router()
        let presenter = PreferredDietPresenter(interactor: Interactor(), router: router)
        presenter.selectedDiet = .balanced

        presenter.navigateToCalorieFloor()

        #expect(router.delegates.isEmpty)
        #expect(router.distributionDelegates.map(\.calorieFloor) == [.standard])
        #expect(router.distributionDelegates.first?.isFromSettings == false)
    }

    /// The same screens are reachable from settings to rebuild an existing plan, and that flag
    /// rides all the way to the last screen — it is what sends the user back to settings rather
    /// than onwards into the rest of onboarding.
    @Test("Test Arriving From Settings Is Carried Onwards")
    func testArrivingFromSettingsIsCarriedOnwards() {
        let router = Router()
        let presenter = PreferredDietPresenter(interactor: Interactor(), router: router, isFromSettings: true)
        presenter.selectedDiet = .balanced

        presenter.navigateToCalorieFloor()

        #expect(router.delegates.first?.isFromSettings == true)
    }
}

// MARK: - How low calories may go

/// The floor is the safety limit under the whole plan: whatever the maths works out, no day is
/// allowed below it.
@MainActor
struct OnboardingCalorieFloorPresenterTests {

    private final class Interactor: SpyGlobalInteractor, CalorieFloorInteractor { }

    private final class Router: CalorieFloorRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var delegates: [CalorieDistributionDelegate] = []

        func showDevSettingsView() { }
        func showCalorieDistributionView(delegate: CalorieDistributionDelegate) { delegates.append(delegate) }
    }

    private func makePresenter(router: Router) -> CalorieFloorPresenter {
        CalorieFloorPresenter(interactor: Interactor(), router: router)
    }

    /// The screen opens with the safer of the two options already chosen, so a user who reads
    /// nothing and presses Continue gets the recommended limit rather than no limit.
    @Test("Test The Screen Opens On The Recommended Floor")
    func testTheScreenOpensOnTheRecommendedFloor() {
        let interactor = Interactor()
        let presenter = CalorieFloorPresenter(interactor: interactor, router: Router())

        #expect(presenter.selectedFloor == .standard)
        #expect(interactor.trackedEventNames == ["Onboarding_CalFloor_Prefilled"])
    }

    /// The two floors are the numbers the plan is clamped to, and the descriptions on the screen
    /// promise these figures by name.
    @Test("Test The Floors Are 1200 And 800 Calories")
    func testTheFloorsAre1200And800Calories() {
        #expect(CalorieFloor.standard.minimumValue == 1200)
        #expect(CalorieFloor.low.minimumValue == 800)
    }

    @Test("Test The Chosen Floor And The Earlier Diet Are Both Carried")
    func testTheChosenFloorAndTheEarlierDietAreBothCarried() {
        let router = Router()
        let presenter = makePresenter(router: router)
        presenter.selectedFloor = .low

        presenter.onContinuePressed(delegate: CalorieFloorDelegate(preferredDiet: .lowCarb))

        #expect(router.delegates.first?.calorieFloor == .low)
        #expect(router.delegates.first?.preferredDiet == .lowCarb)
    }

    @Test("Test Clearing The Floor Does Not Move On")
    func testClearingTheFloorDoesNotMoveOn() {
        let router = Router()
        let presenter = makePresenter(router: router)
        presenter.selectedFloor = nil

        presenter.onContinuePressed(delegate: CalorieFloorDelegate(preferredDiet: .balanced))

        #expect(router.delegates.isEmpty)
    }

    @Test("Test Arriving From Settings Is Carried Onwards")
    func testArrivingFromSettingsIsCarriedOnwards() {
        let router = Router()
        let presenter = makePresenter(router: router)

        presenter.onContinuePressed(delegate: CalorieFloorDelegate(preferredDiet: .balanced, isFromSettings: true))

        #expect(router.delegates.first?.isFromSettings == true)
    }
}

// MARK: - Flat week or varied week

/// Whether calories are spread evenly or pushed towards training days. The screen prefills its
/// answer from the training mesocycle the user built two steps earlier.
@MainActor
struct OnboardingCalorieDistributionTests {

    private final class Interactor: SpyGlobalInteractor, CalorieDistributionInteractor {
        var activeMesocycle: Mesocycle?

        init(activeMesocycle: Mesocycle? = nil) {
            self.activeMesocycle = activeMesocycle
        }
    }

    private final class Router: CalorieDistributionRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var delegates: [ProteinIntakeDelegate] = []

        func showDevSettingsView() { }
        func showProteinIntakeView(delegate: ProteinIntakeDelegate) { delegates.append(delegate) }
    }

    /// A mesocycle's weekly cycle is its templates; a template with no exercises is a rest day.
    private func mesocycle(trainingDays: Int, restDays: Int = 0) -> Mesocycle {
        let days = (0..<trainingDays).map { index in
            WorkoutTemplateModel(
                id: "training-\(index)",
                authorId: "user-1",
                name: "Day \(index)",
                exercises: [WorkoutTemplateExercise(exercise: ExerciseModel.mock, setRestTimers: false)]
            )
        }
        let rests = (0..<restDays).map { index in
            WorkoutTemplateModel(id: "rest-\(index)", authorId: "user-1", name: "Rest \(index)", exercises: [])
        }
        return Mesocycle(
            id: "program-1",
            authorId: "user-1",
            name: "Block",
            icon: "flag",
            colour: "#FF0000",
            workoutTemplates: days + rests
        )
    }

    /// Three sessions a week is not enough variation to be worth carb-cycling, so the flat week
    /// is offered.
    @Test("Test A Light Training Week Prefills An Even Split")
    func testALightTrainingWeekPrefillsAnEvenSplit() {
        let interactor = Interactor(activeMesocycle: mesocycle(trainingDays: 3, restDays: 4))
        let presenter = CalorieDistributionPresenter(interactor: interactor, router: Router())

        #expect(presenter.selectedCalorieDistribution == .even)
        #expect(presenter.trainingDaysPerWeek == 3)
        #expect(presenter.hasMesocycle)
    }

    /// Four or more and the suggestion flips, so the extra calories land on the days they are
    /// used.
    @Test("Test A Heavy Training Week Prefills A Varied Split")
    func testAHeavyTrainingWeekPrefillsAVariedSplit() {
        let interactor = Interactor(activeMesocycle: mesocycle(trainingDays: 5, restDays: 2))
        let presenter = CalorieDistributionPresenter(interactor: interactor, router: Router())

        #expect(presenter.selectedCalorieDistribution == .varied)
        #expect(presenter.trainingDaysPerWeek == 5)
    }

    /// Rest days are templates too. Counting them would tip a three-session week over the
    /// four-day threshold and suggest carb-cycling a week that has nothing to cycle around.
    @Test("Test Rest Days Are Not Counted As Training Days")
    func testRestDaysAreNotCountedAsTrainingDays() {
        let interactor = Interactor(activeMesocycle: mesocycle(trainingDays: 2, restDays: 5))
        let presenter = CalorieDistributionPresenter(interactor: interactor, router: Router())

        #expect(presenter.trainingDaysPerWeek == 2)
        #expect(presenter.selectedCalorieDistribution == .even)
    }

    /// A mesocycle of nothing but rest days is a real shape — a user can build one and activate it.
    /// Zero training days must fall on the flat week rather than suggesting the user cycle carbs
    /// around sessions they do not have.
    @Test("Test A Program With No Training Days Prefills An Even Split")
    func testAMesocycleWithNoTrainingDaysPrefillsAnEvenSplit() {
        let interactor = Interactor(activeMesocycle: mesocycle(trainingDays: 0, restDays: 7))
        let presenter = CalorieDistributionPresenter(interactor: interactor, router: Router())

        #expect(presenter.trainingDaysPerWeek == 0)
        #expect(presenter.selectedCalorieDistribution == .even)
        // The mesocycle exists, so the screen may still say it read one.
        #expect(presenter.hasMesocycle)
    }

    /// Without a mesocycle there is nothing to base a suggestion on, so the user is left to choose
    /// rather than shown a guess dressed up as a recommendation.
    @Test("Test With No Program Nothing Is Prefilled")
    func testWithNoMesocycleNothingIsPrefilled() {
        let presenter = CalorieDistributionPresenter(interactor: Interactor(), router: Router())

        #expect(presenter.selectedCalorieDistribution == nil)
        #expect(presenter.trainingDaysPerWeek == nil)
        #expect(!presenter.hasMesocycle)
    }

    @Test("Test Nothing Chosen Does Not Move On")
    func testNothingChosenDoesNotMoveOn() {
        let router = Router()
        let presenter = CalorieDistributionPresenter(interactor: Interactor(), router: router)

        presenter.navigateToProteinIntake(delegate: CalorieDistributionDelegate(
            delegate: CalorieFloorDelegate(preferredDiet: .balanced),
            calorieFloor: .standard
        ))

        #expect(router.delegates.isEmpty)
    }

    @Test("Test The Earlier Answers Are Carried With The Split")
    func testTheEarlierAnswersAreCarriedWithTheSplit() {
        let router = Router()
        let presenter = CalorieDistributionPresenter(interactor: Interactor(), router: router)
        presenter.selectedCalorieDistribution = .varied

        presenter.navigateToProteinIntake(delegate: CalorieDistributionDelegate(
            delegate: CalorieFloorDelegate(preferredDiet: .lowFat, isFromSettings: true),
            calorieFloor: .low
        ))

        let passed = router.delegates.first
        #expect(passed?.calorieDistrubtion == .varied)
        #expect(passed?.preferredDiet == .lowFat)
        #expect(passed?.calorieFloor == .low)
        #expect(passed?.isFromSettings == true)
    }
}

// MARK: - How much protein

/// The last question, and the one that collects every earlier answer for the plan builder.
@MainActor
struct OnboardingProteinIntakePresenterTests {

    private final class Interactor: SpyGlobalInteractor, ProteinIntakeInteractor {
        var currentUser: UserModel?
    }

    private final class Router: ProteinIntakeRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var delegates: [DietPlanDelegate] = []

        func showDevSettingsView() { }
        func showDietPlanView(delegate: DietPlanDelegate) { delegates.append(delegate) }
    }

    private func incoming(isFromSettings: Bool = false) -> ProteinIntakeDelegate {
        ProteinIntakeDelegate(
            delegate: CalorieDistributionDelegate(
                delegate: CalorieFloorDelegate(preferredDiet: .lowCarb, isFromSettings: isFromSettings),
                calorieFloor: .low
            ),
            calorieDistribution: .varied
        )
    }

    @Test("Test No Protein Level Picked Does Not Move On")
    func testNoProteinLevelPickedDoesNotMoveOn() {
        let router = Router()
        let presenter = ProteinIntakePresenter(interactor: Interactor(), router: router)

        presenter.onContinuePressed(delegate: incoming())

        #expect(router.delegates.isEmpty)
    }

    /// This is the one point where all four answers are together. If any of them is dropped here
    /// the plan is built from a default the user never chose.
    @Test("Test All Four Answers Reach The Plan Builder")
    func testAllFourAnswersReachThePlanBuilder() {
        let router = Router()
        let presenter = ProteinIntakePresenter(interactor: Interactor(), router: router)
        presenter.selectedProteinIntake = .veryHigh

        presenter.onContinuePressed(delegate: incoming(isFromSettings: true))

        let passed = router.delegates.first
        #expect(passed?.proteinIntake == .veryHigh)
        #expect(passed?.preferredDiet == .lowCarb)
        #expect(passed?.calorieFloor == .low)
        #expect(passed?.calorieDistribution == .varied)
        #expect(passed?.isFromSettings == true)
    }
}
