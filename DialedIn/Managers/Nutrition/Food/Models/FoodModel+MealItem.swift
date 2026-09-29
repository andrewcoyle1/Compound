//
//  FoodModel+MealItem.swift
//  DialedIn
//
//  Created by Andrew Coyle on 22/09/2026.
//

import Foundation

extension FoodModel {

    /// The unit a logged amount of this food is counted in. A food is recorded either by mass or
    /// by volume, never both, so there is one answer per food.
    var loggedUnitLabel: String {
        switch measurementMethod {
        case .weight: return "g"
        case .volume: return "ml"
        }
    }

    /// One portion of this food, in `loggedUnitLabel`.
    ///
    /// The food's own stated serving where it has one, and 100 where it has none — that being the
    /// basis its nutrients are recorded against, so a food with no declared portion is logged at
    /// exactly the amount those figures describe.
    var defaultPortionAmount: Double {
        let declared = measurementMethod == .weight ? portionGramsCalculated : portionMillilitersCalculated
        guard let declared, declared.isFinite, declared > 0 else { return 100 }
        return declared
    }

    /// This food as a meal item at `amount` of `unit`, or of `loggedUnitLabel` when no serving
    /// unit is given — "2 slice" is stored as two of a slice, resolved to its grams.
    ///
    /// Nutrients are stored per 100 g/ml, which is what the scale divides by. Pulled out of
    /// `IngredientAmountPresenter.add(ingredient:onConfirm:)` so the amount screen and the
    /// quick-add path that skips it build the same item from the same food.
    func mealItem(amount: Double, unit: ServingUnit? = nil) -> MealItemModel {
        let base = NutritionScaling.baseAmount(amount, in: unit)
        return MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .ingredient,
            sourceId: ingredientId,
            displayName: name,
            amount: amount,
            unit: unit?.name ?? loggedUnitLabel,
            resolvedGrams: measurementMethod == .weight ? base : nil,
            resolvedMilliliters: measurementMethod == .volume ? base : nil,
            nutrients: nutrients.scaled(by: base / 100.0)
        )
    }
}
