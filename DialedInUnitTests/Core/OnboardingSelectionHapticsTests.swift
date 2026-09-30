//
//  OnboardingSelectionHapticsTests.swift
//  DialedInUnitTests
//

import Testing
import Foundation
@testable import DialedIn

// Every onboarding option row goes through its presenter, which records the choice and plays the
// selection tick. The rows used to write the choice straight from the view, with no feedback.

@MainActor
struct OnboardingSelectionHapticsTests {

    private final class Interactor: SpyGlobalInteractor, GenderInteractor, ExerciseFrequencyInteractor, ActivityInteractor,
        OverarchingObjectiveInteractor, PreferredDietInteractor, CalorieFloorInteractor,
        CalorieDistributionInteractor, ProteinIntakeInteractor {
        var currentUser: UserModel?
        var activeMesocycle: Mesocycle?
        func readSexFromAppleHealth() async -> Gender? { nil }
    }

    private final class Router: GenderRouter, ExerciseFrequencyRouter, ActivityRouter,
        OverarchingObjectiveRouter, PreferredDietRouter, CalorieFloorRouter, CalorieDistributionRouter, ProteinIntakeRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showDevSettingsView() { }
        func showDateOfBirthView(delegate: DateOfBirthDelegate) { }
        func showActivityView(delegate: ActivityDelegate) { }
        func showExpenditureView(delegate: ExpenditureDelegate) { }
        func showTargetWeightView(delegate: TargetWeightDelegate) { }
        func showGoalSummaryView(delegate: GoalSummaryDelegate) { }
        func showCalorieFloorView(delegate: CalorieFloorDelegate) { }
        func showCalorieDistributionView(delegate: CalorieDistributionDelegate) { }
        func showProteinIntakeView(delegate: ProteinIntakeDelegate) { }
        func showDietPlanView(delegate: DietPlanDelegate) { }
    }

    private func haptics(_ interactor: Interactor) -> [String] {
        interactor.playedHaptics.map { "\($0)" }
    }

    @Test("Choosing a profile answer records it and plays the selection tick")
    func testProfileAnswersTick() {
        let interactor = Interactor()
        let router = Router()

        let gender = GenderPresenter(interactor: interactor, router: router)
        gender.onGenderSelected(.female)
        #expect(gender.selectedGender == .female)

        let frequency = ExerciseFrequencyPresenter(interactor: interactor, router: router)
        frequency.onFrequencySelected(.threeToFour)
        #expect(frequency.selectedFrequency == .threeToFour)

        let activity = ActivityPresenter(interactor: interactor, router: router)
        let level = ActivityLevel.allCases[1]
        activity.onActivityLevelSelected(level)
        #expect(activity.selectedActivityLevel == level)

        let objective = OverarchingObjectivePresenter(interactor: interactor, router: router)
        objective.onObjectiveSelected(.loseWeight)
        #expect(objective.selectedObjective == .loseWeight)

        // Four, not five: the cardio fitness step left onboarding (decision 8c).
        #expect(haptics(interactor) == Array(repeating: "selection", count: 4))
    }

    @Test("Choosing a diet answer records it and plays the selection tick")
    func testDietAnswersTick() {
        let interactor = Interactor()
        let router = Router()

        let diet = PreferredDietPresenter(interactor: interactor, router: router)
        diet.onDietSelected(.balanced)
        #expect(diet.selectedDiet == .balanced)

        let floor = CalorieFloorPresenter(interactor: interactor, router: router)
        floor.onFloorSelected(.low)
        #expect(floor.selectedFloor == .low)

        let distribution = CalorieDistributionPresenter(interactor: interactor, router: router)
        distribution.onDistributionSelected(.even)
        #expect(distribution.selectedCalorieDistribution == .even)

        let protein = ProteinIntakePresenter(interactor: interactor, router: router)
        protein.onProteinIntakeSelected(.moderate)
        #expect(protein.selectedProteinIntake == .moderate)

        #expect(haptics(interactor) == Array(repeating: "selection", count: 4))
    }
}
