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
}

extension FoodModel {

    /// One portion as the user thinks of it: the food's named portion where it has one ("1 slice",
    /// "0.5 cup"), otherwise `defaultPortionAmount` of grams or millilitres. The amount screen opens
    /// on it and a never-logged "+" adds it, so the two agree.
    var defaultPortion: (amount: Double, unit: ServingUnit?) {
        if let name = portionNameCalculated, let unit = servingUnits.first(where: { $0.name == name }) {
            return (portionQuantityCalculated ?? 1, unit)
        }
        return (defaultPortionAmount, nil)
    }

    /// What a picker row's "+" puts on the plate without the amount screen: this food at the
    /// amount and unit it was last logged at, since most foods are eaten in the same quantity each
    /// time, or its default portion if it has never been logged.
    func quickAddItem(lastLoggedIn meals: [MealLogModel]) -> MealItemModel {
        let isThisFood = { (item: MealItemModel) in item.sourceType == .ingredient && item.sourceId == ingredientId }
        guard let last = meals
            .filter({ $0.items.contains(where: isThisFood) })
            .max(by: { $0.date < $1.date })?
            .items.last(where: isThisFood) else {
            return mealItem(amount: defaultPortion.amount, unit: defaultPortion.unit)
        }
        return mealItem(amount: last.amount, unit: servingUnits.first { $0.name == last.unit })
    }
}

extension RecipeTemplateModel {

    /// This recipe as a meal item of `servings` servings: per serving first, then by how many
    /// were eaten. Scaling the whole recipe by the servings instead logged the entire pot for
    /// every serving. Shared by the amount screen and every quick add, which used to build the
    /// item three ways and log different figures for the same recipe.
    func mealItem(servings: Double) -> MealItemModel {
        MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .recipe,
            sourceId: recipeId,
            displayName: name,
            amount: servings,
            unit: "serving",
            resolvedGrams: nil,
            resolvedMilliliters: nil,
            nutrients: NutritionScaling.nutrients(of: self).scaled(by: NutritionScaling.factor(servings: servings, of: self))
        )
    }

    /// The recipe's "+": the servings last logged, or one.
    func quickAddItem(lastLoggedIn meals: [MealLogModel]) -> MealItemModel {
        let isThisRecipe = { (item: MealItemModel) in item.sourceType == .recipe && item.sourceId == recipeId }
        let last = meals
            .filter { $0.items.contains(where: isThisRecipe) }
            .max { $0.date < $1.date }?
            .items.last(where: isThisRecipe)
        return mealItem(servings: last?.amount ?? 1)
    }
}

extension Array where Element == MealLogModel {

    /// The foods most recently eaten, newest first and each once, as the search screen's "Recent".
    /// By the meals' dates: the collection comes back in storage order, which this used to take
    /// as the order they were eaten.
    func recentFoods(from foods: [FoodModel], limit: Int = 20) -> [FoodModel] {
        let byId = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<String>()
        var result: [FoodModel] = []
        for meal in sorted(by: { $0.date > $1.date }) {
            for item in meal.items.reversed() where item.sourceType == .ingredient && seen.insert(item.sourceId).inserted {
                guard let food = byId[item.sourceId] else { continue }
                result.append(food)
                if result.count == limit { return result }
            }
        }
        return result
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
