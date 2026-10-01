//
//  NutritionManagerTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The one diet plan a user has, and the estimate underneath it.
///
/// Two separable jobs live in this manager. One is the document: a single `DietPlan` mirrored from
/// Firestore, read by the food log every time it draws a ring. The other is `estimateTDEE`, which
/// is pure arithmetic over the profile and is what every calorie figure in the app ultimately
/// descends from.
///
/// The seven-day arithmetic that turns an estimate into a plan is covered by
/// `NutritionManagerDietPlanTests` and `OnboardingDietPlanMathTests`; this file covers the
/// document, the weekday lookup and the estimate.
@MainActor
struct NutritionManagerTests {

    // MARK: - Fixtures

    /// A plan whose seven days are labelled by their own index, so a lookup that returns the wrong
    /// day is identifiable rather than merely unequal.
    private func indexedPlan(planId: String = "plan-1", days: Int = 7) -> DietPlan {
        DietPlan(
            planId: planId,
            userId: "user-1",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            tdeeEstimate: 2500,
            preferredDiet: PreferredDiet.balanced.rawValue,
            calorieFloor: CalorieFloor.standard.rawValue,
            trainingType: "moderate",
            calorieDistribution: CalorieDistribution.even.rawValue,
            proteinIntake: ProteinIntake.moderate.rawValue,
            days: (0..<days).map { index in
                DailyMacroTarget(
                    calories: Double(index),
                    proteinGrams: 150,
                    carbGrams: 250,
                    fatGrams: 70
                )
            }
        )
    }

    /// A profile whose body figures are fixed rather than derived from `Date()`, so two reads of
    /// one agree. The date of birth is deliberately not today's.
    private func profile(
        weightKilograms: Double? = 80,
        heightCentimeters: Double? = 180,
        gender: Gender? = .male,
        exerciseFrequency: ExerciseFrequency? = .threeToFour,
        dailyActivity: ActivityLevel? = .moderate,
        ageYears: Int? = 36
    ) -> UserModel {
        UserModel(
            userId: "user-1",
            submittedDateOfBirth: ageYears.map { yearsAgo($0) },
            submittedGender: gender,
            submittedHeightCentimeters: heightCentimeters,
            submittedWeightKilograms: weightKilograms,
            submittedExerciseFrequency: exerciseFrequency,
            submittedDailyActivityLevel: dailyActivity
        )
    }

    /// A birthday `years` ago and one day, so the whole-year count the manager takes cannot land a
    /// day short of the age the test means.
    private func yearsAgo(_ years: Int) -> Date {
        let calendar = Calendar.current
        let birthday = calendar.date(byAdding: .year, value: -years, to: Date()) ?? Date()
        return calendar.date(byAdding: .day, value: -1, to: birthday) ?? birthday
    }

    /// Mifflin-St Jeor times the activity multiplier, spelled out here so the expectation is the
    /// published equation rather than a copy of the implementation's structure.
    private func mifflinTDEE(
        weightKg: Double,
        heightCm: Double,
        age: Double,
        isMale: Bool,
        multiplier: Double
    ) -> Double {
        let bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + (isMale ? 5 : -161)
        return max(1000, bmr * multiplier)
    }

    // MARK: - The stored plan

    @Test("Test The Plan Is Hidden Until Signed In")
    func testThePlanIsHiddenUntilSignedIn() {
        #expect(TestManagers.nutritionManager(plan: indexedPlan()).currentDietPlan == nil)
    }

    @Test("Test Signing In Exposes The Stored Plan")
    func testSigningInExposesTheStoredPlan() async throws {
        let plan = indexedPlan()

        let manager = try await TestManagers.signedInNutritionManager(plan: plan)

        #expect(manager.currentDietPlan == plan)
    }

    /// One account's targets must not still be on screen while another signs in — the food log
    /// draws its rings straight off `currentDietPlan`.
    @Test("Test Signing Out Hides The Plan")
    func testSigningOutHidesThePlan() async throws {
        let manager = try await TestManagers.signedInNutritionManager(plan: indexedPlan())
        #expect(manager.currentDietPlan != nil)

        manager.signOut()

        #expect(manager.currentDietPlan == nil)
    }

    @Test("Test Saving A Plan Makes It Current")
    func testSavingAPlanMakesItCurrent() async throws {
        let manager = try await TestManagers.signedInNutritionManager(plan: nil)

        try await manager.saveDietPlan(indexedPlan())

        #expect(await TestManagers.eventually { manager.currentDietPlan?.planId == "plan-1" })
    }

    /// Rebuilding the plan from the diet settings saves over the old one rather than adding a
    /// second — there is only ever one plan, and the food log reads whichever is current.
    @Test("Test Saving Over A Plan Replaces It")
    func testSavingOverAPlanReplacesIt() async throws {
        let manager = try await TestManagers.signedInNutritionManager(plan: indexedPlan())

        let original = indexedPlan()
        let replacement = DietPlan(
            planId: original.planId,
            userId: original.userId,
            createdAt: original.createdAt,
            tdeeEstimate: 3100,
            preferredDiet: PreferredDiet.keto.rawValue,
            calorieFloor: original.calorieFloor,
            trainingType: original.trainingType,
            calorieDistribution: original.calorieDistribution,
            proteinIntake: original.proteinIntake,
            days: original.days
        )
        try await manager.saveDietPlan(replacement)

        #expect(await TestManagers.eventually { manager.currentDietPlan?.tdeeEstimate == 3100 })
        #expect(manager.currentDietPlan?.preferredDiet == PreferredDiet.keto.rawValue)
    }

    @Test("Test Deleting The Plan Clears It")
    func testDeletingThePlanClearsIt() async throws {
        let manager = try await TestManagers.signedInNutritionManager(plan: indexedPlan())

        try await manager.deleteDietPlan()

        #expect(await TestManagers.eventually { manager.currentDietPlan == nil })
    }

    /// The engine deletes the document id it was told to listen to, so a delete before sign-in has
    /// no id to work from. It has to refuse rather than delete whatever it last saw.
    @Test("Test Deleting Before Signing In Throws")
    func testDeletingBeforeSigningInThrows() async {
        let manager = TestManagers.nutritionManager(plan: indexedPlan())

        await #expect(throws: (any Error).self) {
            try await manager.deleteDietPlan()
        }
    }

    // MARK: - The day's target

    @Test("Test No Plan Means No Daily Target")
    func testNoPlanMeansNoDailyTarget() async throws {
        let manager = TestManagers.nutritionManager(plan: indexedPlan())

        let target = try await manager.getDailyTarget(for: Date(), userId: "user-1")

        #expect(target == nil)
    }

    /// The plan is stored Monday-first while `Calendar` counts weekdays Sunday-first, so the
    /// lookup shifts by five and wraps. Sweeping a whole week rather than one day because the
    /// arithmetic is only wrong at the wrap: an off-by-one puts every day's targets on the day
    /// before or after it, and Sunday is the day that reads from the opposite end of the array.
    @Test("Test Every Weekday Reads Its Own Day Of The Plan")
    func testEveryWeekdayReadsItsOwnDayOfThePlan() async throws {
        let manager = try await TestManagers.signedInNutritionManager(plan: indexedPlan())
        let monday = try #require(mondayNoon())
        #expect(Calendar.current.component(.weekday, from: monday) == 2)

        for offset in 0..<7 {
            let date = try #require(Calendar.current.date(byAdding: .day, value: offset, to: monday))
            let target = try await manager.getDailyTarget(for: date, userId: "user-1")

            // Each day of the fixture carries its own index as its calorie figure.
            #expect(target?.calories == Double(offset))
        }
    }

    /// Named on its own because Sunday is the wrap: `(1 + 5) % 7` is the only weekday whose index
    /// comes from the modulo rather than straight addition.
    @Test("Test Sunday Reads The Last Day Of The Plan")
    func testSundayReadsTheLastDayOfThePlan() async throws {
        let manager = try await TestManagers.signedInNutritionManager(plan: indexedPlan())
        let monday = try #require(mondayNoon())
        let sunday = try #require(Calendar.current.date(byAdding: .day, value: 6, to: monday))
        #expect(Calendar.current.component(.weekday, from: sunday) == 1)

        let target = try await manager.getDailyTarget(for: sunday, userId: "user-1")

        #expect(target?.calories == 6)
    }

    /// A plan that arrives short — an older document, or a half-written one — must report no
    /// target for the missing days rather than reading off the end of the array.
    @Test("Test A Short Plan Has No Target For The Days It Is Missing")
    func testAShortPlanHasNoTargetForTheDaysItIsMissing() async throws {
        let manager = try await TestManagers.signedInNutritionManager(plan: indexedPlan(days: 3))
        let monday = try #require(mondayNoon())

        let tuesday = try #require(Calendar.current.date(byAdding: .day, value: 1, to: monday))
        let tuesdayTarget = try await manager.getDailyTarget(for: tuesday, userId: "user-1")
        #expect(tuesdayTarget?.calories == 1)

        let friday = try #require(Calendar.current.date(byAdding: .day, value: 4, to: monday))
        let fridayTarget = try await manager.getDailyTarget(for: friday, userId: "user-1")
        #expect(fridayTarget == nil)
    }

    /// The `userId` argument is not read: there is one plan per signed-in account and the manager
    /// is already listening to it. Pinned so a caller passing the wrong id is understood to be
    /// harmless rather than assumed to be filtering.
    @Test("Test The Daily Target Ignores The User Id It Is Given")
    func testTheDailyTargetIgnoresTheUserIdItIsGiven() async throws {
        let manager = try await TestManagers.signedInNutritionManager(plan: indexedPlan())
        let monday = try #require(mondayNoon())

        let mine = try await manager.getDailyTarget(for: monday, userId: "user-1")
        let someoneElses = try await manager.getDailyTarget(for: monday, userId: "user-99")

        #expect(mine == someoneElses)
    }

    /// A Monday at noon. Noon rather than midnight so a clock change cannot move the date, and
    /// 5 January 2026 rather than "the Monday of this week" so the fixture never drifts.
    private func mondayNoon() -> Date? {
        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 12))
    }

    // MARK: - The estimate

    /// The plan can be rebuilt from settings by a profile that never finished onboarding, so a
    /// missing one has to estimate from the documented defaults rather than return zero: 70kg,
    /// 175cm, 30 years old, male, moderately active, training three to four times a week.
    @Test("Test A Missing Profile Still Estimates")
    func testAMissingProfileStillEstimates() {
        let tdee = TestManagers.nutritionManager().estimateTDEE(user: nil)

        let expected = mifflinTDEE(weightKg: 70, heightCm: 175, age: 30, isMale: true, multiplier: 1.6)
        #expect(abs(tdee - expected) < 0.01)
        #expect(abs(tdee - 2638) < 0.01)
    }

    @Test("Test Mifflin St Jeor Uses The Stored Figures")
    func testMifflinStJeorUsesTheStoredFigures() {
        let tdee = TestManagers.nutritionManager().estimateTDEE(user: profile())

        let expected = mifflinTDEE(weightKg: 80, heightCm: 180, age: 36, isMale: true, multiplier: 1.6)
        #expect(abs(tdee - expected) < 0.01)
    }

    /// The gender coefficient is the whole difference between the two Mifflin variants: 5 against
    /// -161, so 166 calories of basal rate before the activity multiplier.
    @Test("Test Women Read Lower Than Men On The Same Figures")
    func testWomenReadLowerThanMenOnTheSameFigures() {
        let manager = TestManagers.nutritionManager()

        let male = manager.estimateTDEE(user: profile(gender: .male))
        let female = manager.estimateTDEE(user: profile(gender: .female))

        #expect(abs((male - female) - (166 * 1.6)) < 0.01)
    }

    /// Decision 8a: "Prefer not to say" sits halfway between the two, in both equations that
    /// branch on sex (Mifflin's -78 is the midpoint of +5 and -161; Harris-Benedict averages its
    /// two whole equations).
    @Test("Test Prefer Not To Say Reads Halfway Between Men And Women")
    func testPreferNotToSayReadsHalfwayBetweenMenAndWomen() {
        let manager = TestManagers.nutritionManager()

        for equation in [BMREquation.mifflinStJeor, .harrisBenedict] {
            let male = manager.estimateTDEE(user: profile(gender: .male), equation: equation)
            let female = manager.estimateTDEE(user: profile(gender: .female), equation: equation)
            let midpoint = manager.estimateTDEE(user: profile(gender: .preferNotToSay), equation: equation)

            #expect(abs(midpoint - (male + female) / 2) < 0.01)
        }
    }

    /// Harris-Benedict is the older equation and reads high, which is what the settings screen
    /// tells the user. If it ever read lower than Mifflin that caption would be wrong.
    @Test("Test Harris Benedict Reads Higher Than Mifflin On The Same Figures")
    func testHarrisBenedictReadsHigherThanMifflinOnTheSameFigures() {
        let manager = TestManagers.nutritionManager()
        let user = profile()

        let harris = manager.estimateTDEE(user: user, equation: .harrisBenedict)
        let mifflin = manager.estimateTDEE(user: user, equation: .mifflinStJeor)

        #expect(harris > mifflin)
    }

    /// Katch-McArdle works from lean mass, so with no logged body fat percentage it has nothing to
    /// work from. Falling back to Mifflin is the documented behaviour; inventing a percentage
    /// would quietly change every calorie figure in the app.
    @Test("Test Katch McArdle Without A Body Fat Falls Back To Mifflin")
    func testKatchMcArdleWithoutABodyFatFallsBackToMifflin() {
        let manager = TestManagers.nutritionManager()
        let user = profile()

        let katch = manager.estimateTDEE(user: user, equation: .katchMcArdle, bodyFatPercentage: nil)
        let mifflin = manager.estimateTDEE(user: user, equation: .mifflinStJeor)

        #expect(abs(katch - mifflin) < 0.01)
    }

    @Test("Test Katch McArdle Estimates From Lean Mass")
    func testKatchMcArdleEstimatesFromLeanMass() {
        let tdee = TestManagers.nutritionManager()
            .estimateTDEE(user: profile(), equation: .katchMcArdle, bodyFatPercentage: 30)

        // 80kg at 30% body fat is 56kg of lean mass.
        let expected = (370 + (21.6 * 56)) * 1.6
        #expect(abs(tdee - expected) < 0.01)
    }

    /// A percentage outside 0–100 is not a body composition — it is a bad read off a weigh-in, and
    /// at 100 it produces zero lean mass. Each one has to fall back rather than be multiplied.
    @Test("Test An Unusable Body Fat Percentage Falls Back To Mifflin")
    func testAnUnusableBodyFatPercentageFallsBackToMifflin() {
        let manager = TestManagers.nutritionManager()
        let user = profile()
        let mifflin = manager.estimateTDEE(user: user, equation: .mifflinStJeor)

        for percentage in [0, -5, 100, 150] as [Double] {
            let katch = manager.estimateTDEE(
                user: user,
                equation: .katchMcArdle,
                bodyFatPercentage: percentage
            )

            #expect(abs(katch - mifflin) < 0.01)
        }
    }

    /// Both activity questions feed one multiplier, and both are asked because the user is told
    /// they matter. An answer that changes nothing — or changes the estimate the wrong way — makes
    /// the question a lie.
    @Test("Test The Estimate Rises With Every Step Of Daily Activity")
    func testTheEstimateRisesWithEveryStepOfDailyActivity() {
        let manager = TestManagers.nutritionManager()

        let estimates = ActivityLevel.allCases.map { level in
            manager.estimateTDEE(user: profile(dailyActivity: level))
        }

        #expect(estimates == estimates.sorted())
        #expect(Set(estimates).count == ActivityLevel.allCases.count)
    }

    @Test("Test The Estimate Rises With Every Step Of Exercise Frequency")
    func testTheEstimateRisesWithEveryStepOfExerciseFrequency() {
        let manager = TestManagers.nutritionManager()

        let estimates = ExerciseFrequency.allCases.map { frequency in
            manager.estimateTDEE(user: profile(exerciseFrequency: frequency))
        }

        #expect(estimates == estimates.sorted())
        #expect(Set(estimates).count == ExerciseFrequency.allCases.count)
    }

    /// The estimate has a floor of its own, below the calorie floor the user picks. It exists so
    /// the smallest, oldest, least active profile the pickers allow still produces a number a plan
    /// can be built from.
    @Test("Test The Estimate Never Falls Below A Thousand")
    func testTheEstimateNeverFallsBelowAThousand() {
        let tiny = profile(
            weightKilograms: 30,
            heightCentimeters: 120,
            gender: .female,
            exerciseFrequency: .never,
            dailyActivity: .sedentary,
            ageYears: 100
        )

        #expect(abs(TestManagers.nutritionManager().estimateTDEE(user: tiny) - 1000) < 0.01)
    }

    /// Age drives a five-calorie-per-year term, so a date of birth read as this year would add
    /// hundreds. Fourteen is the floor, and every profile younger than that reads as fourteen.
    @Test("Test An Age Under Fourteen Is Read As Fourteen")
    func testAnAgeUnderFourteenIsReadAsFourteen() {
        let manager = TestManagers.nutritionManager()

        let infant = manager.estimateTDEE(user: profile(ageYears: 2))
        let fourteen = manager.estimateTDEE(user: profile(ageYears: 14))

        #expect(abs(infant - fourteen) < 0.01)
    }

    /// Date of birth is asked for in onboarding, but the plan can be rebuilt from settings by a
    /// profile that never supplied one. Thirty is the stated default, and reading it as zero would
    /// add 150 calories of basal rate to every such account.
    @Test("Test A Missing Date Of Birth Is Read As Thirty")
    func testAMissingDateOfBirthIsReadAsThirty() {
        let manager = TestManagers.nutritionManager()

        let missing = manager.estimateTDEE(user: profile(ageYears: nil))
        let thirty = manager.estimateTDEE(user: profile(ageYears: 30))

        #expect(abs(missing - thirty) < 0.01)
    }

    // MARK: - Clamping the profile figures

    /// Weight and height arrive off a Firestore document as plain `Double`s, so a corrupt or
    /// half-written profile can carry a NaN or an infinity. Everything downstream is printed
    /// through `Int(_:)`, which traps on anything not finite, so the figure has to be replaced by
    /// the same default a missing one uses rather than merely floored.
    @Test("Test A Weight That Is Not A Number Reads As The Default")
    func testAWeightThatIsNotANumberReadsAsTheDefault() {
        let manager = TestManagers.nutritionManager()
        let expected = manager.estimateTDEE(user: profile(weightKilograms: 70))

        for weight in [Double.nan, .infinity, -.infinity] {
            #expect(abs(manager.estimateTDEE(user: profile(weightKilograms: weight)) - expected) < 0.01)
        }
    }

    @Test("Test A Height That Is Not A Number Reads As The Default")
    func testAHeightThatIsNotANumberReadsAsTheDefault() {
        let manager = TestManagers.nutritionManager()
        let expected = manager.estimateTDEE(user: profile(heightCentimeters: 175))

        for height in [Double.nan, .infinity, -.infinity] {
            #expect(abs(manager.estimateTDEE(user: profile(heightCentimeters: height)) - expected) < 0.01)
        }
    }

    /// A finite but absurd figure is held at the edge of the range instead. The top end matters as
    /// much as the bottom: a stored weight of a million kilograms is finite, so nothing else stops
    /// it multiplying through into the macro split.
    @Test("Test An Extreme Weight Is Held At The Edge Of The Range")
    func testAnExtremeWeightIsHeldAtTheEdgeOfTheRange() {
        let manager = TestManagers.nutritionManager()

        #expect(
            abs(manager.estimateTDEE(user: profile(weightKilograms: 1_000_000))
                - manager.estimateTDEE(user: profile(weightKilograms: 500))) < 0.01
        )
        #expect(
            abs(manager.estimateTDEE(user: profile(weightKilograms: 0))
                - manager.estimateTDEE(user: profile(weightKilograms: 30))) < 0.01
        )
    }

    @Test("Test An Extreme Height Is Held At The Edge Of The Range")
    func testAnExtremeHeightIsHeldAtTheEdgeOfTheRange() {
        let manager = TestManagers.nutritionManager()

        #expect(
            abs(manager.estimateTDEE(user: profile(heightCentimeters: 10_000))
                - manager.estimateTDEE(user: profile(heightCentimeters: 260))) < 0.01
        )
        #expect(
            abs(manager.estimateTDEE(user: profile(heightCentimeters: -20))
                - manager.estimateTDEE(user: profile(heightCentimeters: 120))) < 0.01
        )
    }

    /// Whatever the profile carries, the estimate has to be a number the rest of the app can print
    /// and divide by.
    @Test("Test The Estimate Is Always A Usable Number")
    func testTheEstimateIsAlwaysAUsableNumber() {
        let manager = TestManagers.nutritionManager()
        let profiles: [UserModel?] = [
            nil,
            profile(),
            profile(weightKilograms: nil, heightCentimeters: nil, gender: nil),
            profile(weightKilograms: .nan, heightCentimeters: .nan),
            profile(weightKilograms: .infinity, heightCentimeters: -.infinity),
            profile(weightKilograms: 0, heightCentimeters: 0, ageYears: 120)
        ]

        for user in profiles {
            for equation in BMREquation.allCases {
                for bodyFat in [nil, 0, 25, 100] as [Double?] {
                    let tdee = manager.estimateTDEE(
                        user: user,
                        equation: equation,
                        bodyFatPercentage: bodyFat
                    )

                    #expect(tdee.isFinite)
                    #expect(tdee >= 1000)
                }
            }
        }
    }
}
