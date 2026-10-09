//
//  NutritionTargets.swift
//  Compound
//
//  The arithmetic that turns a calorie target and the diet answers into a week of macro targets:
//  the calorie floor, protein, the fat floor, keto's carbohydrate cap, and how a varied week is
//  spread. `NutritionManager.computeDietPlan` assembles the plan from these; they are pure so each
//  rule can be tested on its own.
//
//  Sources, by rule (see `MethodInfo+Nutrition.swift` for what the user is shown):
//  - Floors: the AHA/ACC/TOS prescription ranges start at 1,200 kcal for women and 1,500 for men
//    (Jensen 2014, R69). Diets of 800 kcal or less are clinically supervised by definition (NIDDK,
//    R67; NICE NG246, R68), so the 800 kcal option was removed.
//  - Protein: 1.6 g/kg is where the gain in fat-free mass levels off (Morton 2018, R47); higher
//    tiers suit lean people cutting (Helms 2014, R49). In obesity, total weight overstates need,
//    so it is applied to a reference weight (Weijs 2025, R51; Dekker 2022, R52). People 65 and over
//    get at least 1.2 g/kg (PROT-AGE, Bauer 2013, R53).
//  - Fat: within 20–35% of energy (IOM 2005, R17; Thomas 2016, R55), and at least 0.5 g/kg
//    (Iraki 2019, R57).
//  - Keto: 20–50 g of carbohydrate a day is the usual definition (Feinman 2015, R58); 30 g is
//    Compound's default inside it.
//

import Foundation

enum NutritionTargets {

    // MARK: - Calorie floor

    /// The lowest daily target the plan writes. Women 1,200 and men 1,500 kcal, the bottom of the
    /// AHA/ACC/TOS prescription ranges; 1,350, their midpoint, when sex is not given.
    static func calorieFloor(for gender: Gender?) -> Double {
        switch gender {
        case .female: return 1200
        case .male: return 1500
        case .preferNotToSay, nil: return 1350
        }
    }

    /// The largest deficit a goal may set, as a share of expenditure. Compound's own cap, so the
    /// fastest rate on a small expenditure cannot write a crash diet before the floor is reached.
    static let maximumDeficitShare: Double = 0.25

    // MARK: - Protein

    /// Above this BMI, protein is worked out on a reference weight rather than total weight.
    static let referenceWeightBMI: Double = 30

    /// Grams of protein per kilogram for each answer.
    static func proteinGramsPerKg(_ intake: ProteinIntake) -> Double {
        switch intake {
        case .low: return 1.6
        case .moderate: return 2.0
        case .high: return 2.2
        case .veryHigh: return 2.6
        }
    }

    /// The minimum for people aged 65 and over (PROT-AGE). Every tier is above it today; it holds
    /// if a lower tier is ever added.
    static let olderAdultMinimumGramsPerKg: Double = 1.2
    static let olderAdultAge: Int = 65

    /// The weight protein and the fat floor are worked out on. Total weight below a BMI of 30.
    /// From 30 up, the weight at a BMI of 30 for the person's height, or their goal weight if
    /// that is higher, and never more than they weigh. Without a usable height, total weight.
    static func referenceWeightKg(weightKg: Double, heightCm: Double?, goalWeightKg: Double?) -> Double {
        guard let heightCm, heightCm.isFinite, heightCm > 0 else { return weightKg }
        let heightM = heightCm / 100
        let weightAtThreshold = referenceWeightBMI * heightM * heightM
        guard weightKg > weightAtThreshold else { return weightKg }
        let goal = goalWeightKg.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? 0
        return min(weightKg, max(weightAtThreshold, goal))
    }

    static func proteinGrams(intake: ProteinIntake, referenceWeightKg: Double, ageYears: Int?) -> Double {
        var perKg = proteinGramsPerKg(intake)
        if let ageYears, ageYears >= olderAdultAge {
            perKg = max(perKg, olderAdultMinimumGramsPerKg)
        }
        return perKg * referenceWeightKg
    }

    // MARK: - Fat and carbohydrate

    /// Fat never goes below this many grams per kilogram of reference weight (Iraki 2019).
    static let fatFloorGramsPerKg: Double = 0.5
    /// Nor below this share of the day's calories, the bottom of the AMDR (IOM 2005).
    static let fatFloorEnergyShare: Double = 0.20
    /// Keto's daily carbohydrate, in grams.
    static let ketoCarbGrams: Double = 30

    /// Fat's share of the day for the diets set by fat; carbohydrate's for low-carb. Keto is a gram
    /// cap rather than a share.
    static func fatShare(_ diet: PreferredDiet) -> Double? {
        switch diet {
        case .balanced: return 0.30
        case .lowFat: return 0.20
        case .lowCarb, .keto: return nil
        }
    }

    static let lowCarbEnergyShare: Double = 0.20

    /// One day's grams. Protein is fixed; fat follows the diet, then is raised to the fat floor if
    /// it falls short; carbohydrate takes what is left.
    static func macros(
        calories: Double,
        proteinGrams: Double,
        diet: PreferredDiet,
        referenceWeightKg: Double
    ) -> DailyMacroTarget {
        let remaining = max(calories - proteinGrams * 4, 0)
        var fatCalories: Double
        switch diet {
        case .balanced, .lowFat:
            fatCalories = calories * (fatShare(diet) ?? 0.30)
        case .lowCarb:
            fatCalories = remaining - calories * lowCarbEnergyShare
        case .keto:
            fatCalories = remaining - min(ketoCarbGrams * 4, remaining)
        }
        let floorCalories = max(fatFloorGramsPerKg * referenceWeightKg * 9, fatFloorEnergyShare * calories)
        fatCalories = min(max(fatCalories, floorCalories, 0), remaining)
        let carbCalories = max(remaining - fatCalories, 0)
        return DailyMacroTarget(
            calories: calories.rounded(),
            proteinGrams: proteinGrams.rounded(),
            carbGrams: (carbCalories / 4).rounded(),
            fatGrams: (fatCalories / 9).rounded()
        )
    }

    // MARK: - Calorie distribution

    /// The share added to a high day. Compound's own figure, kept from the earlier fixed split.
    static let highDayBonus: Double = 0.10
    /// No other day drops below this share of the target. Compound's own figure.
    static let lowestDayShare: Double = 0.85

    /// Seven daily calorie targets, Monday first, that total seven times `target`.
    ///
    /// Even: every day at the target. Varied: one high day per training day in the mesocycle,
    /// spread evenly through the week, with the other days lowered to keep the week's total the
    /// same. The mesocycle is a queue rather than a calendar, so the high days cannot be pinned to
    /// the days the user will actually train; they are spread out instead, and the copy says so.
    /// The bonus shrinks when there are many training days so the rest never fall below 85%.
    static func dailyCalories(
        target: Double,
        floor: Double,
        distribution: CalorieDistribution,
        trainingDaysPerWeek: Int
    ) -> [Double] {
        let highDays = min(max(trainingDaysPerWeek, 0), 7)
        guard distribution == .varied, highDays > 0, highDays < 7 else {
            return Array(repeating: max(target, floor), count: 7)
        }
        let restDays = 7 - highDays
        let bonus = min(highDayBonus, (1 - lowestDayShare) * Double(restDays) / Double(highDays))
        let high = target * (1 + bonus)
        let low = target * (1 - bonus * Double(highDays) / Double(restDays))
        let highIndices = Set(highDayIndices(count: highDays))
        return (0..<7).map { max(highIndices.contains($0) ? high : low, floor) }
    }

    /// `count` weekday indices (Monday = 0) spread as evenly as a week allows: 3 gives Monday,
    /// Wednesday and Friday; 4 gives Monday, Tuesday, Thursday and Saturday.
    static func highDayIndices(count: Int) -> [Int] {
        guard count > 0 else { return [] }
        return (0..<min(count, 7)).map { Int((Double($0) * 7 / Double(count)).rounded(.down)) }
    }
}
