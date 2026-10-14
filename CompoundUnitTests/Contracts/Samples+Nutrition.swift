//
//  Samples+Nutrition.swift
//  CompoundUnitTests
//
//  The fixed nutrition samples behind contracts/firestore/{meal_log,meal_item,nutrient_map,
//  diet_plan,daily_macro_target,food_log_settings}. See FirestoreContractTests.swift.
//

import Foundation
@testable import Compound

extension Samples {
    /// Every nutrient, so a new `NutrientKey` changes this fixture and fails until re-recorded.
    static let fullNutrients = NutrientMap(Dictionary(uniqueKeysWithValues: NutrientKey.allCases.enumerated().map {
        ($0.element, Double($0.offset) + 0.5)
    }))

    static let fullMealItem = MealItemModel(
        itemId: "meal_item_contract_full",
        sourceType: .recipe,
        sourceId: "recipe_contract",
        displayName: "Overnight Oats",
        amount: 1.5,
        unit: "serving",
        resolvedGrams: 337.5,
        resolvedMilliliters: 120.25,
        nutrients: fullNutrients
    )

    static let minimalMealItem = MealItemModel(
        itemId: "meal_item_contract_minimal",
        sourceType: .quickAdd,
        sourceId: "quick_add",
        displayName: "Quick add",
        amount: 0.5,
        unit: "serving"
    )

    static let fullMealLog = MealLogModel(
        mealId: "meal_log_contract_full",
        authorId: "user_contract_full",
        dayKey: "2026-10-12",
        date: date("2026-10-12T07:45:30.250Z"),
        items: [fullMealItem, minimalMealItem],
        notes: "Before training"
    )

    static let minimalMealLog = MealLogModel(
        mealId: "meal_log_contract_minimal",
        authorId: "user_contract_minimal",
        dayKey: "2026-10-13",
        date: date("2026-10-13T12:30:00.000Z"),
        items: []
    )

    static let fullDailyMacroTarget = DailyMacroTarget(calories: 2450.5, proteinGrams: 160.25, carbGrams: 280.75, fatGrams: 70.5)

    static let minimalDailyMacroTarget = DailyMacroTarget(calories: 1800.5, proteinGrams: 140.5, carbGrams: 180.25, fatGrams: 60.75)

    static let fullDietPlan = DietPlan(
        planId: "user_contract_full",
        userId: "user_contract_full",
        createdAt: date("2026-09-28T09:15:00.500Z"),
        tdeeEstimate: 2650.5,
        preferredDiet: "balanced",
        calorieFloor: "standard",
        trainingType: "moderate",
        calorieDistribution: "varied",
        proteinIntake: "high",
        days: [
            fullDailyMacroTarget, minimalDailyMacroTarget, fullDailyMacroTarget, minimalDailyMacroTarget,
            fullDailyMacroTarget, minimalDailyMacroTarget, minimalDailyMacroTarget
        ]
    )

    static let minimalDietPlan = DietPlan(
        planId: "diet_plan_contract_minimal",
        userId: nil,
        createdAt: date("2026-09-28T09:15:00.500Z"),
        tdeeEstimate: 2200.5,
        preferredDiet: "keto",
        calorieFloor: "standard",
        trainingType: "none",
        calorieDistribution: "even",
        proteinIntake: "moderate",
        days: []
    )

    /// Every setting away from its default.
    static let fullFoodLogSettings = FoodLogSettings(
        authorId: "user_contract_full",
        showOverages: true,
        showsFoodTimestamps: false,
        showHourlyMacroTotals: false,
        showCalendarWeekBanner: false,
        premove: true,
        timestampSide: .right,
        showAddFoodsButton: false,
        startHour: 5,
        endHour: 21,
        hideFoodDetails: true,
        hideEmptyHours: true,
        showBrandedFoods: false,
        showOpenFoodFactsFoods: false,
        showFoodImageInTimeline: false,
        showCaloriesInTimeline: false,
        showMacrosInTimeline: false,
        showFoodImageInLogger: false,
        showCaloriesInLogger: false,
        showMacrosInLogger: false,
        showPortionInLogger: false,
        showCaloriesRing: false,
        showProteinRing: false,
        showFatRing: false,
        showCarbsRing: false,
        autoSetCurrentTime: true,
        favouriteMeasurements: ["g", "tbsp"],
        favouriteFoodIds: ["food_contract"],
        favouriteRecipeIds: ["recipe_contract"],
        quickAddEnabled: true
    )
}
