//
//  NutritionScaling.swift
//  DialedIn
//
//  Created by Andrew Coyle on 25/09/2026.
//

import Foundation

/// The arithmetic that turns an amount of a food or a recipe into nutrients.
///
/// Nutrients are recorded per 100g (or 100ml). Everything else here is converting some other
/// quantity — an ingredient in a recipe, a serving unit such as a slice, a number of servings —
/// into that basis. Pure functions only, so the recipe detail, the recipe logger and the food
/// logger all read the same figures.
enum NutritionScaling {

    /// Grams (or millilitres) of an ingredient as used in a recipe. Millilitres are taken
    /// one-for-one with grams, and a counted unit as 100g, which is the assumption the recipe
    /// builder makes.
    static func baseAmount(of ingredient: RecipeIngredientModel) -> Double {
        switch ingredient.unit {
        case .grams, .milliliters: return ingredient.amount
        case .units: return ingredient.amount * 100
        }
    }

    /// `amount` of `unit` in grams (or millilitres). No unit means the amount is already in the
    /// food's base unit.
    static func baseAmount(_ amount: Double, in unit: ServingUnit?) -> Double {
        amount * (unit?.grams ?? 1)
    }

    /// The whole recipe's nutrients — every ingredient at the amount the recipe uses. A nutrient
    /// no ingredient records stays absent rather than reading as zero.
    static func nutrients(of recipe: RecipeTemplateModel) -> NutrientMap {
        recipe.ingredients.reduce(NutrientMap()) { total, ingredient in
            total + ingredient.ingredient.nutrients.scaled(by: baseAmount(of: ingredient) / 100)
        }
    }

    /// How many servings the recipe as written makes. Floors at one so a recipe saved claiming no
    /// servings reads as a single serving rather than dividing by zero.
    static func servingDivisor(_ recipe: RecipeTemplateModel) -> Double {
        recipe.servingQuantity.isFinite ? max(recipe.servingQuantity, 1) : 1
    }

    /// One serving's nutrients: the recipe divided across the servings it makes.
    static func perServing(_ recipe: RecipeTemplateModel) -> NutrientMap {
        nutrients(of: recipe).scaled(by: 1 / servingDivisor(recipe))
    }

    /// What to multiply a recipe's amounts by to make `servings` of it. Anything that is not a
    /// usable serving count scales to nothing.
    static func factor(servings: Double, of recipe: RecipeTemplateModel) -> Double {
        guard servings.isFinite, servings > 0 else { return 0 }
        return servings / servingDivisor(recipe)
    }

    /// `value` to `places` decimal places, for showing a scaled amount without a tail of digits.
    /// Not a number reads as zero, since these are printed.
    static func rounded(_ value: Double, places: Int = 1) -> Double {
        guard value.isFinite else { return 0 }
        let scale = pow(10, Double(max(places, 0)))
        return (value * scale).rounded() / scale + 0 // `+ 0` turns -0 into 0
    }
}
