//
//  RecipeTemplateModelTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// A recipe, and the per-serving nutrition worked out from its ingredients.
///
/// The arithmetic here is easy to get subtly wrong and hard to spot: ingredient nutrients are per
/// 100 g, amounts are in grams, millilitres or whole units, and the result is divided by the number
/// of servings. A recipe that forgot to divide would log a whole tray of lasagne as one portion.
@MainActor
struct RecipeTemplateModelTests {

    private let date = Date(timeIntervalSince1970: 1_000_000)

    /// A food with nutrients per 100 g.
    private func food(
        name: String = "Rolled Oats",
        calories: Double = 379,
        protein: Double = 13.2,
        method: MeasurementMethod = .weight
    ) -> FoodModel {
        FoodModel(
            ingredientId: "food-\(name)",
            name: name,
            measurementMethod: method,
            nutrients: [.calories: calories, .protein: protein]
        )
    }

    private func recipe(
        ingredients: [RecipeIngredientModel],
        servings: Double = 1
    ) -> RecipeTemplateModel {
        RecipeTemplateModel(
            id: "recipe-1",
            authorId: "author-1",
            name: "Porridge",
            dateCreated: date,
            dateModified: date,
            ingredients: ingredients,
            servingQuantity: servings
        )
    }

    // MARK: - Totalling by weight

    /// 100 g of a food worth 379 kcal per 100 g is 379 kcal.
    @Test("Test One Hundred Grams Is The Per-Hundred Value")
    func testOneHundredGramsIsThePerHundredValue() {
        let recipe = recipe(ingredients: [RecipeIngredientModel(ingredient: food(), amount: 100, unit: .grams)])

        #expect(recipe.calories == 379)
        #expect(recipe.protein == 13.2)
    }

    @Test("Test Amounts Scale The Nutrients")
    func testAmountsScaleTheNutrients() {
        let half = recipe(ingredients: [RecipeIngredientModel(ingredient: food(), amount: 50, unit: .grams)])
        let double = recipe(ingredients: [RecipeIngredientModel(ingredient: food(), amount: 200, unit: .grams)])

        #expect(half.calories == 189.5)
        #expect(double.calories == 758)
    }

    @Test("Test Ingredients Add Up")
    func testIngredientsAddUp() {
        let recipe = recipe(ingredients: [
            RecipeIngredientModel(ingredient: food(name: "Oats", calories: 379), amount: 50, unit: .grams),
            RecipeIngredientModel(ingredient: food(name: "Milk", calories: 61), amount: 200, unit: .milliliters)
        ])

        #expect(recipe.calories == 189.5 + 122)
    }

    /// A "unit" is treated as 100 g — one egg, one banana — since there is nothing else to go on.
    @Test("Test Whole Units Count As A Hundred Grams Each")
    func testWholeUnitsCountAsAHundredGramsEach() {
        let recipe = recipe(ingredients: [
            RecipeIngredientModel(ingredient: food(calories: 379), amount: 2, unit: .units)
        ])

        #expect(recipe.calories == 758)
    }

    // MARK: - Servings

    /// The headline figure is per serving, not per recipe.
    @Test("Test Nutrition Is Divided Across The Servings")
    func testNutritionIsDividedAcrossTheServings() {
        let ingredients = [RecipeIngredientModel(ingredient: food(calories: 400), amount: 100, unit: .grams)]

        #expect(recipe(ingredients: ingredients, servings: 1).calories == 400)
        #expect(recipe(ingredients: ingredients, servings: 2).calories == 200)
        #expect(recipe(ingredients: ingredients, servings: 4).calories == 100)
    }

    /// A recipe claiming fewer than one serving would multiply its nutrition rather than divide it,
    /// so the divisor is floored at one.
    @Test("Test Fewer Than One Serving Does Not Multiply The Nutrition")
    func testFewerThanOneServingDoesNotMultiplyTheNutrition() {
        let ingredients = [RecipeIngredientModel(ingredient: food(calories: 400), amount: 100, unit: .grams)]

        #expect(recipe(ingredients: ingredients, servings: 0).calories == 400)
        #expect(recipe(ingredients: ingredients, servings: 0.5).calories == 400)
    }

    // MARK: - Missing data

    /// A recipe whose ingredients record nothing has unknown nutrition, not zero — "we do not know"
    /// is different from "it has none", and showing 0 kcal for a real meal would be worse.
    @Test("Test A Recipe With No Recorded Nutrients Is Unknown")
    func testARecipeWithNoRecordedNutrientsIsUnknown() {
        let blank = FoodModel(ingredientId: "blank", name: "Mystery")
        let recipe = recipe(ingredients: [RecipeIngredientModel(ingredient: blank, amount: 100, unit: .grams)])

        #expect(recipe.calories == nil)
        #expect(recipe.protein == nil)
    }

    @Test("Test An Empty Recipe Is Unknown")
    func testAnEmptyRecipeIsUnknown() {
        #expect(recipe(ingredients: []).calories == nil)
    }

    /// One ingredient with data is enough to give a total, even if another has none — the figure is
    /// then a floor rather than nothing at all.
    @Test("Test One Ingredient With Data Is Enough For A Total")
    func testOneIngredientWithDataIsEnoughForATotal() {
        let blank = FoodModel(ingredientId: "blank", name: "Mystery")
        let recipe = recipe(ingredients: [
            RecipeIngredientModel(ingredient: food(calories: 379), amount: 100, unit: .grams),
            RecipeIngredientModel(ingredient: blank, amount: 100, unit: .grams)
        ])

        #expect(recipe.calories == 379)
    }

    /// A food may record calories but not protein; the two are answered independently.
    @Test("Test Nutrients Are Answered Independently")
    func testNutrientsAreAnsweredIndependently() {
        let caloriesOnly = FoodModel(ingredientId: "f", name: "Sugar", nutrients: [.calories: 400])
        let recipe = recipe(ingredients: [RecipeIngredientModel(ingredient: caloriesOnly, amount: 100, unit: .grams)])

        #expect(recipe.calories == 400)
        #expect(recipe.protein == nil)
    }

    // MARK: - Ingredients

    /// The unit follows the food when it is not given: grams for something weighed, millilitres for
    /// something poured.
    @Test("Test An Ingredient Takes Its Unit From The Food")
    func testAnIngredientTakesItsUnitFromTheFood() {
        let weighed = RecipeIngredientModel(ingredient: food(method: .weight), amount: 100)
        let poured = RecipeIngredientModel(ingredient: food(method: .volume), amount: 100)

        #expect(weighed.unit == .grams)
        #expect(poured.unit == .milliliters)
    }

    @Test("Test An Explicit Unit Wins")
    func testAnExplicitUnitWins() {
        let ingredient = RecipeIngredientModel(ingredient: food(method: .weight), amount: 2, unit: .units)

        #expect(ingredient.unit == .units)
    }

    @Test("Test An Ingredient Is Identified By Its Food")
    func testAnIngredientIsIdentifiedByItsFood() {
        let food = food()
        let ingredient = RecipeIngredientModel(ingredient: food, amount: 100)

        #expect(ingredient.id == food.ingredientId)
        #expect(ingredient.name == food.name)
    }

    // MARK: - The recipe itself

    @Test("Test A Recipe Is Identified By Its Recipe Id")
    func testARecipeIsIdentifiedByItsRecipeId() {
        #expect(recipe(ingredients: []).id == "recipe-1")
    }

    @Test("Test A Recipe Is Always Portioned As One Serving")
    func testARecipeIsAlwaysPortionedAsOneServing() {
        let recipe = recipe(ingredients: [], servings: 4)

        #expect(recipe.portionQuantityCalculated == 1)
        #expect(recipe.portionNameCalculated == "serving")
    }

    // MARK: - Stored bad data

    /// Round trips one ingredient through a store that, like Firestore, hands non-finite doubles
    /// back verbatim — plain `JSONEncoder`/`JSONDecoder` refuse them and the hole would never be
    /// reached.
    private func roundTripLeniently(_ ingredient: RecipeIngredientModel) throws -> RecipeIngredientModel {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan"
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan"
        )

        return try decoder.decode(RecipeIngredientModel.self, from: encoder.encode(ingredient))
    }

    /// `RecipeDetailView` and `RecipeStartView` both print the amount through `Int(_:)` while
    /// drawing, which traps on a NaN, and a recipe saved before the entry fields were sanitised can
    /// carry one.
    @Test("Test A Stored Non Finite Ingredient Amount Reads As Zero")
    func testAStoredNonFiniteIngredientAmountReadsAsZero() throws {
        let nan = try roundTripLeniently(RecipeIngredientModel(ingredient: food(), amount: .nan, unit: .grams))
        let infinite = try roundTripLeniently(RecipeIngredientModel(ingredient: food(), amount: .infinity, unit: .grams))

        #expect(nan.amount == 0)
        #expect(infinite.amount == 0)
    }

    /// `Int(_:)` traps on anything that will not fit, not only on the non-finite, so the top is
    /// closed too.
    @Test("Test A Stored Ingredient Amount Too Large To Print Is Capped")
    func testAStoredIngredientAmountTooLargeToPrintIsCapped() throws {
        let absurd = try roundTripLeniently(RecipeIngredientModel(ingredient: food(), amount: 1e30, unit: .grams))

        #expect(absurd.amount == 1_000_000)
    }

    @Test("Test An Ordinary Ingredient Amount Is Unchanged")
    func testAnOrdinaryIngredientAmountIsUnchanged() throws {
        let ordinary = try roundTripLeniently(RecipeIngredientModel(ingredient: food(), amount: 47.5, unit: .grams))

        #expect(ordinary.amount == 47.5)
        #expect(ordinary.unit == .grams)
        #expect(ordinary.ingredient.name == "Rolled Oats")
    }

    @Test("Test A Recipe Round Trips")
    func testARecipeRoundTrips() throws {
        let original = recipe(
            ingredients: [RecipeIngredientModel(ingredient: food(), amount: 50, unit: .grams)],
            servings: 2
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(RecipeTemplateModel.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.servingQuantity == 2)
        #expect(decoded.ingredients.count == 1)
        #expect(decoded.calories == original.calories)
    }
}
