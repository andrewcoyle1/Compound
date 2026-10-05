//
//  OnboardingDietPlanPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The plan itself: the screen that shows the seven days the four answers add up to, and the
/// arithmetic behind them.
///
/// Everything the user eats against for the rest of their time in the app comes out of this one
/// calculation, and it runs once, unseen, during onboarding. A rounding error that gains or loses
/// calories looks fine on Monday and is wrong by Sunday.

/// A user whose body figures are fixed rather than computed from `Date()`, so two reads of one
/// agree. The date of birth is deliberately not today's.
@MainActor
private func dietPlanUser(
    weightKilograms: Double? = 80,
    heightCentimeters: Double? = 180,
    gender: Gender? = .male,
    exerciseFrequency: ExerciseFrequency? = .threeToFour,
    dailyActivity: ActivityLevel? = .moderate,
    yearOfBirth: Int = 1990
) -> UserModel {
    UserModel(
        userId: "user-1",
        submittedDateOfBirth: Calendar.current.date(from: DateComponents(year: yearOfBirth, month: 4, day: 12)),
        submittedGender: gender,
        submittedHeightCentimeters: heightCentimeters,
        submittedWeightKilograms: weightKilograms,
        submittedExerciseFrequency: exerciseFrequency,
        submittedDailyActivityLevel: dailyActivity,
        submittedCardioFitnessLevel: .intermediate
    )
}

@MainActor
private func dietPlanDelegate(
    preferredDiet: PreferredDiet = .balanced,
    calorieFloor: CalorieFloor = .standard,
    calorieDistribution: CalorieDistribution = .even,
    proteinIntake: ProteinIntake = .moderate,
    isFromSettings: Bool = false
) -> DietPlanDelegate {
    DietPlanDelegate(
        oldDelegate: ProteinIntakeDelegate(
            delegate: CalorieDistributionDelegate(
                delegate: CalorieFloorDelegate(preferredDiet: preferredDiet, isFromSettings: isFromSettings),
                calorieFloor: calorieFloor
            ),
            calorieDistribution: calorieDistribution
        ),
        proteinIntake: proteinIntake
    )
}

// MARK: - The arithmetic

/// `computeDietPlan` is pure: given a profile and the four answers it returns seven days. These
/// tests drive the real `NutritionManager`, since the sums are the thing being checked.
@MainActor
struct OnboardingDietPlanMathTests {

    private func manager() -> NutritionManager {
        NutritionManager(dietPlanSyncEngine: TestManagers.documentEngine(nil as DietPlan?, key: "diet-plan"))
    }

    private func mesocycle(trainingDays: Int) -> Mesocycle {
        Mesocycle(
            id: "program-1",
            authorId: "user-1",
            name: "Upper/Lower",
            icon: "flag",
            colour: "#FF0000",
            workoutTemplates: (0..<trainingDays).map { index in
                WorkoutTemplateModel(
                    id: "day-\(index)",
                    authorId: "user-1",
                    name: "Day \(index)",
                    exercises: [WorkoutTemplateExercise(exercise: ExerciseModel.mock, setRestTimers: false)]
                )
            }
        )
    }

    /// The plan is indexed by weekday elsewhere, so a short week would silently leave a day of
    /// the user's week with no target at all.
    @Test("Test A Plan Always Has Seven Days")
    func testAPlanAlwaysHasSevenDays() {
        let plan = manager().computeDietPlan(user: dietPlanUser(), delegate: dietPlanDelegate())

        #expect(plan.days.count == 7)
    }

    @Test("Test A Varied Plan Also Has Seven Days")
    func testAVariedPlanAlsoHasSevenDays() {
        let plan = manager().computeDietPlan(
            user: dietPlanUser(),
            delegate: dietPlanDelegate(calorieDistribution: .varied),
            mesocycle: mesocycle(trainingDays: 4)
        )

        #expect(plan.days.count == 7)
    }

    /// A flat week is flat: every day carries the same target, and that target is the estimate
    /// the screen shows above it.
    @Test("Test An Even Week Puts The Same Target On Every Day")
    func testAnEvenWeekPutsTheSameTargetOnEveryDay() {
        let plan = manager().computeDietPlan(user: dietPlanUser(), delegate: dietPlanDelegate())

        #expect(Set(plan.days.map(\.calories)).count == 1)
        #expect(plan.days.first?.calories == plan.tdeeEstimate)
    }

    /// Varying the week moves calories between days; it must not create or destroy them. Three
    /// higher days and four lower ones have to come back to the same weekly total, or a user on
    /// a varied plan is quietly eating more — or less — than the same user on a flat one.
    @Test("Test A Varied Week Totals The Same As A Flat Week")
    func testAVariedWeekTotalsTheSameAsAFlatWeek() {
        let user = dietPlanUser()
        let flat = manager().computeDietPlan(user: user, delegate: dietPlanDelegate())
        let varied = manager().computeDietPlan(
            user: user,
            delegate: dietPlanDelegate(calorieDistribution: .varied),
            mesocycle: mesocycle(trainingDays: 4)
        )

        let flatTotal = flat.days.reduce(0) { $0 + $1.calories }
        let variedTotal = varied.days.reduce(0) { $0 + $1.calories }
        // Each day is rounded to a whole calorie, so seven days can differ by a few at most.
        #expect(abs(flatTotal - variedTotal) <= 4)
    }

    /// The higher days are the training days, and there are three of them against four lower.
    @Test("Test A Varied Week Has Three Higher Days")
    func testAVariedWeekHasThreeHigherDays() {
        let plan = manager().computeDietPlan(
            user: dietPlanUser(),
            delegate: dietPlanDelegate(calorieDistribution: .varied),
            mesocycle: mesocycle(trainingDays: 4)
        )

        let highest = plan.days.map(\.calories).max() ?? 0
        #expect(plan.days.filter { $0.calories == highest }.count == 3)
        #expect(highest > plan.tdeeEstimate)
    }

    /// Asking to vary the week with no training mesocycle to vary it around leaves a flat week
    /// rather than inventing training days that are not in anyone's calendar.
    @Test("Test Varying Without A Training Program Leaves A Flat Week")
    func testVaryingWithoutAMesocycleLeavesAFlatWeek() {
        let plan = manager().computeDietPlan(
            user: dietPlanUser(),
            delegate: dietPlanDelegate(calorieDistribution: .varied)
        )

        #expect(Set(plan.days.map(\.calories)).count == 1)
    }

    /// The whole point of the floor: a small, old, sedentary user whose estimate lands under it
    /// is fed the floor, not the estimate. The estimate is still reported honestly alongside.
    @Test("Test A Target Below The Floor Is Raised To The Floor")
    func testATargetBelowTheFloorIsRaisedToTheFloor() {
        let frail = dietPlanUser(
            weightKilograms: 30,
            heightCentimeters: 120,
            exerciseFrequency: .never,
            dailyActivity: .sedentary,
            yearOfBirth: 1930
        )

        let plan = manager().computeDietPlan(user: frail, delegate: dietPlanDelegate(calorieFloor: .standard))

        #expect(plan.tdeeEstimate < 1200)
        #expect(plan.days.allSatisfy { $0.calories == 1200 })
    }

    /// Choosing the lower floor lets the same user's plan sit below 1200 — that is what the
    /// option is for — but never below its own limit either.
    @Test("Test The Low Floor Lets The Target Sit Lower")
    func testTheLowFloorLetsTheTargetSitLower() {
        let frail = dietPlanUser(
            weightKilograms: 30,
            heightCentimeters: 120,
            exerciseFrequency: .never,
            dailyActivity: .sedentary,
            yearOfBirth: 1930
        )

        let plan = manager().computeDietPlan(user: frail, delegate: dietPlanDelegate(calorieFloor: .low))

        #expect(plan.days.allSatisfy { $0.calories >= 800 })
        #expect(plan.days.allSatisfy { $0.calories < 1200 })
    }

    /// Protein is grams per kilogram of bodyweight, and the four levels have to be ordered — a
    /// user who picks "Very High" and is given less than "Low" was asked a pointless question.
    @Test("Test Protein Rises With The Level Chosen")
    func testProteinRisesWithTheLevelChosen() {
        let user = dietPlanUser(weightKilograms: 80)
        let grams = [ProteinIntake.low, .moderate, .high, .veryHigh].map { intake in
            manager().computeDietPlan(user: user, delegate: dietPlanDelegate(proteinIntake: intake))
                .days.first?.proteinGrams ?? 0
        }

        #expect(grams == grams.sorted())
        #expect(Set(grams).count == 4)
        // 80kg at the moderate 2.0 g/kg.
        #expect(grams[1] == 160)
    }

    /// Bodyweight is asked for earlier in onboarding, but the plan can be rebuilt from settings
    /// by a profile that never got one. Deriving grams from a missing weight must not produce
    /// zero grams of protein.
    @Test("Test A Missing Bodyweight Still Produces Protein")
    func testAMissingBodyweightStillProducesProtein() {
        let plan = manager().computeDietPlan(
            user: dietPlanUser(weightKilograms: nil),
            delegate: dietPlanDelegate(proteinIntake: .moderate)
        )

        #expect(plan.days.first?.proteinGrams == 140)
    }

    /// And a stored weight of zero — which the pickers cannot produce but a half-written profile
    /// can — is clamped rather than multiplied, so nothing is divided by it further down.
    @Test("Test A Zero Bodyweight Is Clamped Not Multiplied")
    func testAZeroBodyweightIsClampedNotMultiplied() {
        let plan = manager().computeDietPlan(
            user: dietPlanUser(weightKilograms: 0),
            delegate: dietPlanDelegate(proteinIntake: .moderate)
        )

        // The 30kg minimum at 2.0 g/kg.
        #expect(plan.days.first?.proteinGrams == 60)
        #expect(plan.days.allSatisfy { $0.calories > 0 })
    }

    /// The three macros are what the user actually logs against, so they have to add back up to
    /// the calorie target on the same row. Four calories a gram for protein and carbs, nine for
    /// fat.
    @Test("Test Each Day's Macros Add Up To Its Calories")
    func testEachDaysMacrosAddUpToItsCalories() {
        for diet in PreferredDiet.allCases {
            let plan = manager().computeDietPlan(
                user: dietPlanUser(),
                delegate: dietPlanDelegate(preferredDiet: diet, calorieDistribution: .varied),
                mesocycle: mesocycle(trainingDays: 5)
            )

            for day in plan.days {
                let fromMacros = (day.proteinGrams * 4) + (day.carbGrams * 4) + (day.fatGrams * 9)
                // Every figure on the row is rounded to a whole gram or calorie.
                #expect(abs(fromMacros - day.calories) <= 10)
            }
        }
    }

    /// No macro can come out negative, whichever diet is chosen — a target of minus fat is not
    /// something a food log can be kept against.
    @Test("Test No Macro Is Ever Negative")
    func testNoMacroIsEverNegative() {
        for diet in PreferredDiet.allCases {
            let plan = manager().computeDietPlan(
                user: dietPlanUser(weightKilograms: 140),
                delegate: dietPlanDelegate(preferredDiet: diet, calorieFloor: .low, proteinIntake: .veryHigh)
            )

            #expect(plan.days.allSatisfy { $0.proteinGrams >= 0 && $0.carbGrams >= 0 && $0.fatGrams >= 0 })
        }
    }

    /// The screen prints every one of these through `Int(...)`, which traps on a non-finite
    /// Double at draw time — the same shape as the NaN that took the goal summary down. So the
    /// contract is not "does not crash here", it is "every figure is a finite number".
    ///
    /// Sweeping the whole answer matrix rather than one combination because the fat and carb
    /// splits are derived per diet, and only some of them subtract protein from the total.
    @Test("Test Every Figure On Every Day Is A Finite Number")
    func testEveryFigureOnEveryDayIsAFiniteNumber() {
        let profiles: [UserModel?] = [
            nil,
            dietPlanUser(),
            dietPlanUser(weightKilograms: nil, heightCentimeters: nil, gender: nil),
            dietPlanUser(weightKilograms: 0, heightCentimeters: 0),
            dietPlanUser(weightKilograms: -50, heightCentimeters: -50),
            dietPlanUser(weightKilograms: 250, heightCentimeters: 120, exerciseFrequency: .never, dailyActivity: .sedentary)
        ]

        for user in profiles {
            for diet in PreferredDiet.allCases {
                for intake in ProteinIntake.allCases {
                    for floor in CalorieFloor.allCases {
                        let plan = manager().computeDietPlan(
                            user: user,
                            delegate: dietPlanDelegate(preferredDiet: diet, calorieFloor: floor, proteinIntake: intake)
                        )

                        #expect(plan.tdeeEstimate.isFinite)
                        #expect(plan.days.allSatisfy(isFiniteAndSane))
                    }
                }
            }
        }
    }

    /// The same sweep over figures that are not numbers at all.
    ///
    /// Weight and height come back off a Firestore document as plain `Double`s, so a corrupt or
    /// half-written profile can carry a NaN or an infinity. Neither is filtered by a one-sided
    /// `max(value, floor)`: `max` is `y >= x ? y : x`, and every comparison against NaN is false,
    /// so the NaN is returned rather than the floor. From there it multiplies straight through the
    /// protein and macro arithmetic into `Int(_:)` in the view body, which traps.
    ///
    /// Kept apart from the sweep above so the two failure shapes are told apart by name.
    @Test("Test A Body Figure That Is Not A Number Cannot Reach The Plan")
    func testABodyFigureThatIsNotANumberCannotReachThePlan() {
        let profiles: [UserModel] = [
            dietPlanUser(weightKilograms: .nan),
            dietPlanUser(weightKilograms: .infinity),
            dietPlanUser(weightKilograms: -.infinity),
            dietPlanUser(heightCentimeters: .nan),
            dietPlanUser(heightCentimeters: .infinity),
            dietPlanUser(weightKilograms: .nan, heightCentimeters: .nan)
        ]

        for user in profiles {
            for diet in PreferredDiet.allCases {
                let plan = manager().computeDietPlan(
                    user: user,
                    delegate: dietPlanDelegate(preferredDiet: diet, proteinIntake: .veryHigh)
                )

                #expect(plan.tdeeEstimate.isFinite)
                #expect(plan.days.allSatisfy(isFiniteAndSane))
            }
        }
    }

    /// Finite is the floor of the requirement; a plan of zero calories and zero protein would
    /// pass that and still be useless, so the bounds go in the same check.
    private func isFiniteAndSane(_ day: DailyMacroTarget) -> Bool {
        let figures = [day.calories, day.proteinGrams, day.carbGrams, day.fatGrams]
        guard figures.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return false }
        return day.calories >= 800 && day.proteinGrams > 0
    }

    /// A profile with nothing filled in reaches here when the plan is rebuilt from settings by a
    /// user who signed in and skipped ahead. It must still produce a usable week rather than a
    /// week of zeroes.
    @Test("Test A Profile With Nothing Filled In Still Gets A Usable Week")
    func testAProfileWithNothingFilledInStillGetsAUsableWeek() {
        let plan = manager().computeDietPlan(user: nil, delegate: dietPlanDelegate())

        #expect(plan.days.count == 7)
        #expect(plan.days.allSatisfy { $0.calories >= 1200 })
        // The 70kg fallback at the moderate 2.0 g/kg.
        #expect(plan.days.first?.proteinGrams == 140)
        #expect(plan.userId == nil)
    }

    /// The four answers are stored on the plan, so the settings screens can show what was chosen
    /// and rebuild from it later.
    @Test("Test The Plan Records The Answers It Was Built From")
    func testThePlanRecordsTheAnswersItWasBuiltFrom() {
        let plan = manager().computeDietPlan(
            user: dietPlanUser(),
            delegate: dietPlanDelegate(
                preferredDiet: .keto,
                calorieFloor: .low,
                calorieDistribution: .varied,
                proteinIntake: .high
            ),
            mesocycle: mesocycle(trainingDays: 4)
        )

        #expect(plan.preferredDiet == PreferredDiet.keto.rawValue)
        #expect(plan.calorieFloor == CalorieFloor.low.rawValue)
        #expect(plan.calorieDistribution == CalorieDistribution.varied.rawValue)
        #expect(plan.proteinIntake == ProteinIntake.high.rawValue)
        #expect(plan.trainingType == "Upper/Lower")
        #expect(plan.userId == "user-1")
    }
}

// MARK: - The screen

/// Shows the plan and saves it. Saving is what makes the whole of onboarding's diet half stick,
/// so a failure here must not be mistaken for success.
@MainActor
struct OnboardingDietPlanScreenTests {

    private final class Interactor: DietPlanInteractor {
        var currentUser: UserModel?
        var saveError: Error?
        var completeError: Error?
        private(set) var completedOnboardingCount = 0
        private(set) var playedHaptics: [HapticOption] = []
        private(set) var computedFor: [UserModel?] = []
        private(set) var savedPlans: [DietPlan] = []
        private(set) var trackedEventNames: [String] = []

        var plan: DietPlan = DietPlan(
            planId: "plan-1",
            userId: "user-1",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            tdeeEstimate: 2800,
            preferredDiet: PreferredDiet.balanced.rawValue,
            calorieFloor: CalorieFloor.standard.rawValue,
            trainingType: "moderate",
            calorieDistribution: CalorieDistribution.even.rawValue,
            proteinIntake: ProteinIntake.moderate.rawValue,
            days: (0..<7).map { _ in
                DailyMacroTarget(calories: 2800, proteinGrams: 160, carbGrams: 300, fatGrams: 93)
            }
        )

        func computeDietPlan(user: UserModel?, delegate: DietPlanDelegate) -> DietPlan {
            computedFor.append(user)
            return plan
        }

        func saveDietPlan(_ plan: DietPlan) async throws {
            if let saveError {
                throw saveError
            }
            savedPlans.append(plan)
        }

        func saveOnboardingComplete() async throws {
            if let completeError { throw completeError }
            completedOnboardingCount += 1
        }

        func trackEvent(event: LoggableEvent) { trackedEventNames.append(event.eventName) }
        func trackScreenEvent(event: LoggableEvent) { trackedEventNames.append(event.eventName) }
        func playHaptic(option: HapticOption) { playedHaptics.append(option) }
    }

    /// `showSimpleAlert` is a `GlobalRouter` requirement, so the failure message is observable.
    /// `dismissScreen` and `dismissModal` are extension-only and dispatch statically, so the
    /// settings path is asserted by what it does *not* show instead.
    private final class Router: DietPlanRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var shown: [String] = []
        private(set) var alertTitles: [String] = []

        func showDevSettingsView() { shown.append("devSettings") }
        func switchToCoreModule() { shown.append("coreModule") }
        func showSimpleAlert(title: String, subtitle: String?) { alertTitles.append(title) }
    }

    private struct Screen {
        let presenter: DietPlanPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        interactor.currentUser = dietPlanUser()
        let router = Router()
        return Screen(
            presenter: DietPlanPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// The plan is built from the signed-in profile, not from whatever the screen was handed.
    @Test("Test The Plan Is Built For The Signed In User")
    func testThePlanIsBuiltForTheSignedInUser() {
        let screen = makeScreen()

        screen.presenter.createPlan(delegate: dietPlanDelegate())

        #expect(screen.interactor.computedFor.first??.userId == "user-1")
        #expect(screen.presenter.plan?.planId == "plan-1")
    }

    /// Nothing computed yet means nothing to save, and certainly nothing to move on from.
    @Test("Test Continuing Before The Plan Exists Saves Nothing")
    func testContinuingBeforeThePlanExistsSavesNothing() {
        let screen = makeScreen()

        screen.presenter.navigate()

        #expect(screen.interactor.savedPlans.isEmpty)
        #expect(screen.router.shown.isEmpty)
    }

    /// The plan is the last answer, so accepting it finishes onboarding there and then, as the
    /// completion screen's Finish does, instead of showing that screen for one more press.
    @Test("Test Accepting The Plan Saves It And Finishes Onboarding")
    func testAcceptingThePlanSavesItAndFinishesOnboarding() async {
        let screen = makeScreen()
        screen.presenter.createPlan(delegate: dietPlanDelegate())

        screen.presenter.navigate()

        #expect(await TestManagers.eventually { screen.router.shown == ["coreModule"] })
        #expect(screen.interactor.savedPlans.first?.planId == "plan-1")
        #expect(screen.interactor.completedOnboardingCount == 1)
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    /// A plan that saved while the profile did not leaves onboarding unfinished, so the user stays
    /// here and is told, rather than being let into the app.
    @Test("Test A Failed Finish Is Surfaced And Goes Nowhere")
    func testAFailedFinishIsSurfacedAndGoesNowhere() async {
        let screen = makeScreen()
        screen.interactor.completeError = URLError(.notConnectedToInternet)
        screen.presenter.createPlan(delegate: dietPlanDelegate())

        screen.presenter.navigate()

        #expect(await TestManagers.eventually { !screen.router.alertTitles.isEmpty })
        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.playedHaptics.isEmpty)
    }

    /// Rebuilding the plan from settings has to go back to settings. Carrying on into the Strava
    /// step would drop a user who is already using the app back into onboarding.
    @Test("Test Rebuilding From Settings Does Not Enter Onboarding")
    func testRebuildingFromSettingsDoesNotEnterOnboarding() async {
        let screen = makeScreen()
        screen.presenter.createPlan(delegate: dietPlanDelegate(isFromSettings: true))

        screen.presenter.navigate()

        #expect(await TestManagers.eventually { !screen.interactor.savedPlans.isEmpty })
        // The settings path dismisses the screen, which cannot be observed through a double.
        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.completedOnboardingCount == 0)
    }

    /// If the plan did not save, the user must not be walked on as though it had — they would
    /// finish onboarding with no targets at all, and a food log with nothing to log against.
    @Test("Test A Failed Save Is Surfaced And Goes Nowhere")
    func testAFailedSaveIsSurfacedAndGoesNowhere() async {
        let screen = makeScreen()
        screen.interactor.saveError = URLError(.notConnectedToInternet)
        screen.presenter.createPlan(delegate: dietPlanDelegate())

        screen.presenter.navigate()

        #expect(await TestManagers.eventually { !screen.router.alertTitles.isEmpty })
        #expect(screen.router.alertTitles == ["Unable to update your profile"])
        #expect(screen.router.shown.isEmpty)
        #expect(screen.interactor.trackedEventNames.contains("DietView_SaveDietPlan_Fail"))
    }
}
