//
//  MealItemModel.swift
//  Compound
//
//  Created by Andrew Coyle on 01/03/2026.
//

import Foundation

struct MealItemModel: DataSyncModelProtocol, Hashable {
    var id: String { itemId }
    let itemId: String
    let sourceType: MealItemSourceType
    let sourceId: String
    let displayName: String
    // Measurement entered by user
    let amount: Double
    let unit: String // e.g., "g", "ml", "serving"
    // Resolved standardized amounts for nutrition calculations when available
    let resolvedGrams: Double?
    let resolvedMilliliters: Double?
    // Full nutrient snapshot at time of logging
    let nutrients: NutrientMap

    // Backward-compat computed wrappers
    var calories: Double? { nutrients[.calories] }
    var proteinGrams: Double? { nutrients[.protein] }
    var carbGrams: Double? { nutrients[.carbs] }
    var fatGrams: Double? { nutrients[.fatTotal] }

    init(
        itemId: String,
        sourceType: MealItemSourceType,
        sourceId: String,
        displayName: String,
        amount: Double,
        unit: String,
        resolvedGrams: Double? = nil,
        resolvedMilliliters: Double? = nil,
        nutrients: NutrientMap = NutrientMap()
    ) {
        self.itemId = itemId
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.displayName = displayName
        self.amount = amount
        self.unit = unit
        self.resolvedGrams = resolvedGrams
        self.resolvedMilliliters = resolvedMilliliters
        self.nutrients = nutrients
    }
}

extension MealItemModel {
    static var mock: MealItemModel {
        MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .ingredient,
            sourceId: "ingredient-123",
            displayName: "Chicken Breast",
            amount: 200,
            unit: "g",
            resolvedGrams: 200,
            resolvedMilliliters: nil,
            nutrients: [.calories: 330, .protein: 62, .carbs: 0, .fatTotal: 7]
        )
    }

    static let mocks: [MealItemModel] = [
        MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .ingredient,
            sourceId: "ing-1",
            displayName: "Oatmeal",
            amount: 50,
            unit: "g",
            resolvedGrams: 50,
            resolvedMilliliters: nil,
            nutrients: [.calories: 190, .protein: 7, .carbs: 32, .fatTotal: 3.5]
        ),
        MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .ingredient,
            sourceId: "ing-2",
            displayName: "Banana",
            amount: 1,
            unit: "unit",
            resolvedGrams: 120,
            resolvedMilliliters: nil,
            nutrients: [.calories: 105, .protein: 1.3, .carbs: 27, .fatTotal: 0.4]
        ),
        MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .ingredient,
            sourceId: "ing-3",
            displayName: "Almond Butter",
            amount: 20,
            unit: "g",
            resolvedGrams: 20,
            resolvedMilliliters: nil,
            nutrients: [.calories: 120, .protein: 4, .carbs: 4, .fatTotal: 10]
        ),
        MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .ingredient,
            sourceId: "ing-4",
            displayName: "Greek Yogurt",
            amount: 150,
            unit: "g",
            resolvedGrams: 150,
            resolvedMilliliters: nil,
            nutrients: [.calories: 135, .protein: 18, .carbs: 8, .fatTotal: 3.5]
        ),
        MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .recipe,
            sourceId: "recipe-1",
            displayName: "Protein Smoothie",
            amount: 1,
            unit: "serving",
            resolvedGrams: nil,
            resolvedMilliliters: 350,
            nutrients: [.calories: 280, .protein: 32, .carbs: 25, .fatTotal: 8]
        )
    ]
}
