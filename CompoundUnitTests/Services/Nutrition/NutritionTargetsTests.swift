//
//  NutritionTargetsTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The rules `computeDietPlan` assembles a plan from, each against the source it rests on.
struct NutritionTargetsTests {

    // MARK: - Protein

    /// Below a BMI of 30, protein is on total weight.
    @Test("Test Protein Is On Total Weight Below A BMI Of 30")
    func testProteinIsOnTotalWeightBelowABMIOf30() {
        let reference = NutritionTargets.referenceWeightKg(weightKg: 80, heightCm: 180, goalWeightKg: nil)

        #expect(reference == 80)
        #expect(abs(NutritionTargets.proteinGrams(intake: .low, referenceWeightKg: reference, ageYears: 30) - 128) < 0.001)
    }

    /// From a BMI of 30, total weight overstates need (Weijs 2025): a 130 kg, 1.75 m person is
    /// worked out on the 91.9 kg a BMI of 30 gives at their height, 147 g at 1.6 g/kg rather than
    /// 208 g.
    @Test("Test Protein Uses The BMI 30 Weight In Obesity")
    func testProteinUsesTheBMI30WeightInObesity() {
        let reference = NutritionTargets.referenceWeightKg(weightKg: 130, heightCm: 175, goalWeightKg: nil)

        #expect(abs(reference - 91.875) < 0.0001)
        #expect(abs(NutritionTargets.proteinGrams(intake: .low, referenceWeightKg: reference, ageYears: 40) - 147) < 0.01)
    }

    /// A goal weight above the BMI 30 weight is used instead, but never more than they weigh.
    @Test("Test A Higher Goal Weight Is Used But Never Above Current Weight")
    func testAHigherGoalWeightIsUsed() {
        #expect(NutritionTargets.referenceWeightKg(weightKg: 130, heightCm: 175, goalWeightKg: 110) == 110)
        #expect(NutritionTargets.referenceWeightKg(weightKg: 130, heightCm: 175, goalWeightKg: 80) == 91.875)
        #expect(NutritionTargets.referenceWeightKg(weightKg: 130, heightCm: 175, goalWeightKg: 150) == 130)
    }

    /// Without a usable height there is no BMI, so total weight stands.
    @Test("Test No Height Means Total Weight")
    func testNoHeightMeansTotalWeight() {
        for height in [nil, 0, -.infinity, .nan] as [Double?] {
            #expect(NutritionTargets.referenceWeightKg(weightKg: 130, heightCm: height, goalWeightKg: nil) == 130)
        }
    }

    /// PROT-AGE: at least 1.2 g/kg from 65. Every tier is above it, so it changes nothing today.
    @Test("Test Older Adults Never Get Less Than 1.2 g Per kg")
    func testOlderAdultsNeverGetLessThanTheirMinimum() {
        for intake in ProteinIntake.allCases {
            #expect(NutritionTargets.proteinGrams(intake: intake, referenceWeightKg: 70, ageYears: 70) >= 1.2 * 70)
        }
    }

    // MARK: - Fat and carbohydrate

    /// Fat never drops below 0.5 g per kilogram: a low-fat day of 1,500 kcal for a 100 kg person
    /// is 33 g at 20%, under their 50 g floor (Iraki 2019).
    @Test("Test The Fat Floor Holds On A Low Fat Diet")
    func testTheFatFloorHolds() {
        let day = NutritionTargets.macros(calories: 1500, proteinGrams: 160, diet: .lowFat, referenceWeightKg: 100)

        #expect(day.fatGrams == 50)
        #expect(abs(day.proteinGrams * 4 + day.carbGrams * 4 + day.fatGrams * 9 - 1500) <= 10)
    }

    /// Nor below 20% of the day's calories, the bottom of the AMDR.
    @Test("Test Fat Never Drops Below A Fifth Of The Day")
    func testFatNeverDropsBelowAFifthOfTheDay() {
        for diet in PreferredDiet.allCases {
            let day = NutritionTargets.macros(calories: 2500, proteinGrams: 150, diet: diet, referenceWeightKg: 60)
            #expect(day.fatGrams * 9 >= 0.20 * 2500 - 9)
        }
    }

    /// Keto is 30 g of carbohydrate whatever the calories (Feinman 2015: 20–50 g a day).
    @Test("Test Keto Is A Thirty Gram Cap", arguments: [1800.0, 2500.0, 3500.0])
    func testKetoIsAThirtyGramCap(calories: Double) {
        let day = NutritionTargets.macros(calories: calories, proteinGrams: 150, diet: .keto, referenceWeightKg: 80)

        #expect(day.carbGrams == 30)
    }

    /// Protein claiming the whole day leaves nothing negative.
    @Test("Test Protein Swallowing The Day Leaves Nothing Negative")
    func testProteinSwallowingTheDayLeavesNothingNegative() {
        for diet in PreferredDiet.allCases {
            let day = NutritionTargets.macros(calories: 1000, proteinGrams: 300, diet: diet, referenceWeightKg: 80)
            #expect(day.fatGrams == 0 && day.carbGrams == 0)
        }
    }

    // MARK: - Floors

    @Test("Test The Floor Is Set By Sex")
    func testTheFloorIsSetBySex() {
        #expect(NutritionTargets.calorieFloor(for: .female) == 1200)
        #expect(NutritionTargets.calorieFloor(for: .male) == 1500)
        #expect(NutritionTargets.calorieFloor(for: .preferNotToSay) == 1350)
        #expect(NutritionTargets.calorieFloor(for: nil) == 1350)
    }

    // MARK: - Distribution

    /// High days are spread through the week: three give Monday, Wednesday and Friday.
    @Test("Test High Days Are Spread Evenly")
    func testHighDaysAreSpreadEvenly() {
        #expect(NutritionTargets.highDayIndices(count: 1) == [0])
        #expect(NutritionTargets.highDayIndices(count: 2) == [0, 3])
        #expect(NutritionTargets.highDayIndices(count: 3) == [0, 2, 4])
        #expect(NutritionTargets.highDayIndices(count: 4) == [0, 1, 3, 5])
        #expect(NutritionTargets.highDayIndices(count: 6) == [0, 1, 2, 3, 4, 5])
    }

    /// Whatever the number of training days, the week totals seven times the target, and no day
    /// drops below 85% of it.
    @Test("Test A Varied Week Keeps Its Total And Its Lowest Day", arguments: 1...6)
    func testAVariedWeekKeepsItsTotal(trainingDays: Int) {
        let days = NutritionTargets.dailyCalories(target: 2400, floor: 1200, distribution: .varied, trainingDaysPerWeek: trainingDays)

        // Totalled first: inside #expect the literals left the type checker to time out.
        let weekTotal: Double = days.reduce(0, +)
        #expect(days.count == 7)
        #expect(abs(weekTotal - 7 * 2400) < 0.001)
        #expect(days.allSatisfy { $0 >= 0.85 * 2400 - 0.001 })
        #expect(days.filter { $0 > 2400 }.count == trainingDays)
    }

    /// Three training days keep the earlier figures: 10% up, 7.5% down.
    @Test("Test Three Training Days Keep The Earlier Split")
    func testThreeTrainingDaysKeepTheEarlierSplit() {
        let days = NutritionTargets.dailyCalories(target: 2000, floor: 1200, distribution: .varied, trainingDaysPerWeek: 3)

        let expected: [Double] = [2200, 1850, 2200, 1850, 2200, 1850, 1850]
        for (actual, wanted) in zip(days, expected) {
            #expect(abs(actual - wanted) < 0.001)
        }
    }
}

/// The formula estimate both the manager and onboarding run.
struct FormulaExpenditureTests {

    private let man = FormulaExpenditure.Body(gender: .male, weightKg: 80, heightCm: 180, ageYears: 36, bodyFatPercentage: nil)

    /// Digestion is 10% of the total (Westerterp 2004), and the three parts add up to it.
    @Test("Test The Parts Add Up And Digestion Is A Tenth")
    func testThePartsAddUp() {
        let estimate = FormulaExpenditure.estimate(equation: .mifflinStJeor, body: man, activity: .moderate)

        #expect(abs(estimate.restingKcal - 1750) < 0.0001)
        #expect(abs(estimate.totalKcal - 2975) < 0.0001)
        #expect(abs(estimate.thermicEffectKcal - 297.5) < 0.0001)
        #expect(abs(estimate.restingKcal + estimate.activityKcal + estimate.thermicEffectKcal - estimate.totalKcal) < 0.0001)
    }

    /// Cunningham 1980: 500 + 22 × fat-free mass. 80 kg at 15% is 68 kg fat-free, 1,996 kcal.
    @Test("Test Cunningham Uses Fat-Free Mass")
    func testCunninghamUsesFatFreeMass() {
        let lean = FormulaExpenditure.Body(gender: .male, weightKg: 80, heightCm: 180, ageYears: 36, bodyFatPercentage: 15)

        #expect(abs(FormulaExpenditure.restingKcal(equation: .cunningham, body: lean) - 1996) < 0.0001)
    }

    /// Every PAL sits inside the FAO/WHO/UNU 2004 bands (1.40–2.40), and they rise with activity.
    @Test("Test Every PAL Is Inside The Published Bands")
    func testEveryPALIsInsideThePublishedBands() {
        let pals = ActivityLevel.allCases.map(FormulaExpenditure.activityMultiplier(for:))

        #expect(pals.allSatisfy { $0 >= 1.4 && $0 <= 2.4 })
        #expect(pals == pals.sorted())
        #expect(Set(pals).count == pals.count)
    }
}

/// Weight-goal timelines and the trend weight progress reads.
struct GoalTimelineTests {

    @Test("Test Weeks Are Distance Over Rate Rounded Up")
    func testWeeksAreDistanceOverRate() {
        #expect(GoalTimeline.weeks(distanceKg: 10, weeklyRateKg: 0.5) == 20)
        #expect(GoalTimeline.weeks(distanceKg: -10, weeklyRateKg: 0.3) == 34)
        #expect(GoalTimeline.weeks(distanceKg: 0, weeklyRateKg: 0) == 0)
        #expect(GoalTimeline.weeks(distanceKg: 5, weeklyRateKg: 0) == 0)
    }

    /// About 24 kcal a day per kilogram (Hall 2011).
    @Test("Test The Target Moves About 24 kcal A Day Per Kilogram")
    func testTheTargetMoves() {
        #expect(GoalTimeline.targetChangeKcal(distanceKg: -10) == 240)
    }

    @Test("Test Lean Is A BMI Under 25, Or No Height")
    func testLeanIsABMIUnder25() {
        #expect(GoalTimeline.isLean(weightKg: 80, heightCm: 180))
        #expect(GoalTimeline.isLean(weightKg: 90, heightCm: 180) == false)
        #expect(GoalTimeline.isLean(weightKg: 90, heightCm: nil))
    }

    /// The trend skips deleted and weightless entries and has one value per live weigh-in.
    @Test("Test The Trend Covers Every Live Weigh-In")
    func testTheTrendCoversEveryLiveWeighIn() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = [
            BodyMeasurementEntry(authorId: "a", weightKg: 80, date: start),
            BodyMeasurementEntry(authorId: "a", weightKg: nil, date: start.addingTimeInterval(86_400)),
            BodyMeasurementEntry(authorId: "a", weightKg: 79, date: start.addingTimeInterval(2 * 86_400), deletedAt: start),
            BodyMeasurementEntry(authorId: "a", weightKg: 79.5, date: start.addingTimeInterval(3 * 86_400))
        ]

        let trend = GoalTimeline.trend(of: entries)

        #expect(trend.count == 2)
        #expect(trend.allSatisfy { $0.trendKg.isFinite })
        #expect(GoalTimeline.latestTrendWeightKg(of: []) == nil)
    }
}
