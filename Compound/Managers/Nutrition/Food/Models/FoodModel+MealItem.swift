//
//  FoodModel+MealItem.swift
//  Compound
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

    /// The amount and unit `item` was logged at, read back against this food, so logging it again
    /// repeats last time's amount. A unit this food no longer has falls back to the grams or
    /// millilitres the item resolved to; nil when there is nothing usable to read.
    func loggedAmount(of item: MealItemModel) -> (amount: Double, unit: ServingUnit?)? {
        guard item.amount.isFinite, item.amount > 0 else { return nil }
        if item.unit == loggedUnitLabel { return (item.amount, nil) }
        if let unit = servingUnits.first(where: { $0.name == item.unit }) { return (item.amount, unit) }
        let base = measurementMethod == .weight ? item.resolvedGrams : item.resolvedMilliliters
        guard let base, base.isFinite, base > 0 else { return nil }
        return (base, nil)
    }
}

extension Array where Element == MealItemModel {
    /// How many times this food is already on the plate, for the checkmark-and-count a picker row
    /// shows in place of "+" once a food has been added.
    func addedCount(forIngredientId ingredientId: String) -> Int {
        filter { $0.sourceType == .ingredient && $0.sourceId == ingredientId }.count
    }

    /// The recipe equivalent of `addedCount(forIngredientId:)`.
    func addedCount(forRecipeId recipeId: String) -> Int {
        filter { $0.sourceType == .recipe && $0.sourceId == recipeId }.count
    }
}

extension FoodModel {

    /// A food's nutrients are stored per 100 g or ml, but its row names its portion, so the row
    /// scales them to the portion Quick Add logs. It printed the per-100 g figures beside the
    /// portion: olive oil read "884 kcal · 1 tbsp".
    var rowNutrientScale: Double {
        defaultPortionAmount / 100
    }

    /// The portion's own name when it has a declared weight or volume, else the amount itself.
    var rowPortionText: String? {
        let declared = measurementMethod == .weight ? portionGramsCalculated : portionMillilitersCalculated
        let hasDeclaredAmount = declared.map { $0.isFinite && $0 > 0 } ?? false
        if hasDeclaredAmount, let quantity = portionQuantityCalculated, let name = portionNameCalculated {
            return "\(quantity.formatted()) \(name)"
        }
        let unit = measurementMethod == .weight ? "g" : "ml"
        return "\(defaultPortionAmount.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
    }
}
