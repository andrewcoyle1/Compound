//
//  Samples+Programs.swift
//  CompoundUnitTests
//
//  The fixed samples behind contracts/firestore/{mesocycle,macrocycle,food_model,recipe_template}. See
//  FirestoreContractTests.swift.
//

import Foundation
@testable import Compound

extension Samples {
    /// A training day and a rest day (a template with no exercises), both already under contract
    /// in `workout_template`.
    static let fullMesocycle = Mesocycle(
        id: "mesocycle_contract_full",
        authorId: "user_contract_full",
        name: "Autumn Strength",
        icon: "dumbbell",
        colour: "#FF3B30",
        numMicrocycles: 6,
        deload: .end,
        periodisation: true,
        workoutTemplates: [fullWorkoutTemplate, minimalWorkoutTemplate],
        dateCreated: date("2026-08-03T09:00:00.250Z"),
        dateModified: date("2026-10-04T10:30:00.500Z")
    )

    /// Every field is required. An empty plan is replaced by a random rest day in `init`, so the
    /// sample passes one day of its own.
    static let minimalMesocycle = Mesocycle(
        id: "mesocycle_contract_minimal",
        authorId: "user_contract_minimal",
        name: "Block",
        icon: "flag",
        colour: "#007AFF",
        workoutTemplates: [minimalWorkoutTemplate],
        dateCreated: date("2026-08-04T09:00:00.000Z"),
        dateModified: date("2026-08-04T09:00:00.000Z")
    )

    static let fullMacrocycle = Macrocycle(
        id: "macrocycle_contract_full",
        authorId: "user_contract_full",
        name: "Autumn",
        mesocycleIds: ["mesocycle_contract_full", "mesocycle_contract_minimal"],
        status: .completed,
        mesocycleIndex: 1,
        mesocycleStartedAt: date("2026-09-14T06:00:00.125Z"),
        startMicrocycleIndex: 2,
        skips: [
            CycleSkip(
                mesocycleIndex: 0, cycleIndex: 3, position: 1, templateId: "template_contract_full",
                date: date("2026-09-02T18:00:00.750Z")
            ),
            CycleSkip(
                mesocycleIndex: 1, cycleIndex: 0, position: 0, templateId: "template_contract_minimal",
                date: date("2026-09-15T07:30:00.500Z")
            )
        ],
        iteration: 2,
        dateCreated: date("2026-08-05T09:00:00.250Z"),
        dateModified: date("2026-10-05T11:00:00.500Z")
    )

    static let minimalMacrocycle = Macrocycle(
        id: "macrocycle_contract_minimal",
        authorId: "user_contract_minimal",
        name: "Block",
        mesocycleIds: ["mesocycle_contract_minimal"],
        mesocycleStartedAt: date("2026-08-06T09:00:00.000Z"),
        dateCreated: date("2026-08-06T09:00:00.000Z"),
        dateModified: date("2026-08-06T09:00:00.000Z")
    )

    static let fullFood = FoodModel(
        ingredientId: "food_contract_full",
        authorId: "user_contract_full",
        name: "Oat Milk",
        brandName: "Oatly",
        description: "Barista edition",
        measurementMethod: .volume,
        nutrients: fullNutrients,
        barcode: "7394376616501",
        servingWeight: 250.5,
        portionSize: 1.5,
        portionName: "glass",
        portionWeight: 30.25,
        weightPortionSize: 0.5,
        weightPortionName: "scoop",
        portionVolume: 240.5,
        volumePortionSize: 1.25,
        volumePortionName: "cup",
        imageURL: "https://example.com/oat-milk.jpg",
        dateCreated: date("2026-07-01T08:00:00.250Z"),
        dateModified: date("2026-10-06T12:00:00.750Z"),
        clickCount: 12,
        bookmarkCount: 3,
        favouriteCount: 1
    )

    static let minimalFood = FoodModel(
        ingredientId: "food_contract_minimal",
        name: "Water",
        dateCreated: date("2026-07-02T08:00:00.000Z"),
        dateModified: date("2026-07-02T08:00:00.000Z")
    )

    /// One ingredient per unit, the first carrying the full food, so the nested food is under
    /// the contract too.
    static let fullRecipe = RecipeTemplateModel(
        id: "recipe_contract_full",
        authorId: "user_contract_full",
        name: "Overnight Oats",
        description: "Soaked overnight",
        imageURL: "https://example.com/overnight-oats.jpg",
        dateCreated: date("2026-07-03T08:00:00.250Z"),
        dateModified: date("2026-10-06T12:30:00.750Z"),
        ingredients: [
            RecipeIngredientModel(ingredient: fullFood, amount: 250.5, unit: .milliliters),
            RecipeIngredientModel(ingredient: minimalFood, amount: 80.25, unit: .grams),
            RecipeIngredientModel(ingredient: minimalFood, amount: 1.5, unit: .units)
        ],
        clickCount: 4,
        bookmarkCount: 2,
        favouriteCount: 1,
        servingQuantity: 2.5,
        totalWeight: 412.75,
        preparationSteps: ["Mix the oats and milk.", "Chill overnight."],
        prepTimeMins: 5.5,
        cookTimeMins: 0.5,
        sourceURL: "https://example.com/recipes/overnight-oats"
    )

    /// `click_count`, `bookmark_count` and `favourite_count` default to 0 in the initialiser, so
    /// they are cleared here to leave only what a document must hold. The serving count is always
    /// written; it is not a whole number so the fixture keeps it a double.
    static let minimalRecipe = RecipeTemplateModel(
        id: "recipe_contract_minimal",
        authorId: "user_contract_minimal",
        name: "Toast",
        dateCreated: date("2026-07-04T08:00:00.000Z"),
        dateModified: date("2026-07-04T08:00:00.000Z"),
        clickCount: nil,
        bookmarkCount: nil,
        favouriteCount: nil,
        servingQuantity: 1.5
    )
}
