//
//  NutritionScalingTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 25/09/2026.
//

import Testing
import Foundation
@testable import Compound

/// The pure maths behind recipe scaling and serving units.
struct NutritionScalingTests {

    /// 400g of a 150kcal/100g food, making `servings`: 600kcal in the pot.
    private func recipe(servings: Double, grams: Double = 400) -> RecipeTemplateModel {
        RecipeTemplateModel.newRecipeTemplate(
            name: "Chilli",
            authorId: "user-1",
            ingredients: [
                RecipeIngredientModel(
                    ingredient: FoodModel(name: "Mince", nutrients: NutrientMap([.calories: 150])),
                    amount: grams,
                    unit: .grams
                )
            ],
            servingQuantity: servings
        )
    }

    // MARK: - Rounding

    @Test("Test Rounding Keeps One Decimal Place")
    func testRoundingKeepsOneDecimalPlace() {
        #expect(NutritionScaling.rounded(133.333) == 133.3)
        #expect(NutritionScaling.rounded(2.25) == 2.3)
        #expect(NutritionScaling.rounded(2.25, places: 0) == 2)
    }

    @Test("Test Rounding Something That Is Not A Number Reads As Zero")
    func testRoundingSomethingThatIsNotANumberReadsAsZero() {
        #expect(NutritionScaling.rounded(.nan) == 0)
        #expect(NutritionScaling.rounded(.infinity) == 0)
        #expect(NutritionScaling.rounded(-0.01).sign == .plus)
    }

    // MARK: - Zero

    @Test("Test Zero Servings Scale To Nothing")
    func testZeroServingsScaleToNothing() {
        #expect(NutritionScaling.factor(servings: 0, of: recipe(servings: 4)) == 0)
        #expect(NutritionScaling.factor(servings: -1, of: recipe(servings: 4)) == 0)
        #expect(NutritionScaling.factor(servings: .nan, of: recipe(servings: 4)) == 0)
    }

    @Test("Test A Recipe Claiming Zero Servings Is One Serving")
    func testARecipeClaimingZeroServingsIsOneServing() {
        #expect(NutritionScaling.servingDivisor(recipe(servings: 0)) == 1)
        #expect(NutritionScaling.servingDivisor(recipe(servings: .nan)) == 1)
        #expect(NutritionScaling.perServing(recipe(servings: 0))[.calories] == 600)
    }

    @Test("Test An Empty Recipe Has No Nutrients")
    func testAnEmptyRecipeHasNoNutrients() {
        let empty = RecipeTemplateModel.newRecipeTemplate(name: "Air", authorId: "user-1")
        #expect(NutritionScaling.nutrients(of: empty)[.calories] == nil)
    }

    // MARK: - Fractional servings

    @Test("Test Half A Serving Is Half Of One")
    func testHalfAServingIsHalfOfOne() {
        let chilli = recipe(servings: 4)
        #expect(NutritionScaling.factor(servings: 0.5, of: chilli) == 0.125)
        #expect(NutritionScaling.perServing(chilli)[.calories] == 150)
    }

    @Test("Test Doubling A Recipe Doubles Every Amount")
    func testDoublingARecipeDoublesEveryAmount() {
        let chilli = recipe(servings: 4)
        let factor = NutritionScaling.factor(servings: 8, of: chilli)
        #expect(factor == 2)
        #expect(NutritionScaling.nutrients(of: chilli).scaled(by: factor)[.calories] == 1200)
    }

    @Test("Test A Counted Unit Is Taken As One Hundred Grams")
    func testACountedUnitIsTakenAsOneHundredGrams() {
        let egg = RecipeIngredientModel(ingredient: FoodModel(name: "Egg"), amount: 2, unit: .units)
        #expect(NutritionScaling.baseAmount(of: egg) == 200)
    }

    // MARK: - Serving units

    @Test("Test A Serving Unit Converts To Grams")
    func testAServingUnitConvertsToGrams() {
        #expect(NutritionScaling.baseAmount(2.5, in: ServingUnit(name: "slice", grams: 30)) == 75)
        #expect(NutritionScaling.baseAmount(40, in: nil) == 40)
    }

    /// Rolled oats declare 40g as half a cup, so one cup is 80g.
    @Test("Test A Foods Serving Units Come From Its Declared Portions")
    func testAFoodsServingUnitsComeFromItsDeclaredPortions() {
        #expect(FoodModel.mockRolledOats.servingUnits == [ServingUnit(name: "cup", grams: 80)])
        #expect(FoodModel.mockOliveOil.servingUnits == [ServingUnit(name: "tbsp", grams: 14)])
        #expect(FoodModel(name: "Plain").servingUnits.isEmpty)
    }

    /// A portion named after the base unit ("150 ml is 150 ml") is not another unit.
    @Test("Test A Portion Named After The Base Unit Is Not Offered")
    func testAPortionNamedAfterTheBaseUnitIsNotOffered() {
        let sauce = FoodModel(
            name: "Sauce", measurementMethod: .volume,
            portionVolume: 150, volumePortionSize: 150, volumePortionName: "ml"
        )
        #expect(sauce.servingUnits.isEmpty)
    }

    @Test("Test A Meal Item In A Serving Unit Resolves To Grams")
    func testAMealItemInAServingUnitResolvesToGrams() {
        let bread = FoodModel(name: "Bread", nutrients: NutrientMap([.calories: 250]))
        let item = bread.mealItem(amount: 2, unit: ServingUnit(name: "slice", grams: 40))

        #expect(item.amount == 2)
        #expect(item.unit == "slice")
        #expect(item.resolvedGrams == 80)
        #expect(item.nutrients[.calories] == 200)
    }
}

/// A picker row's "+" puts the food on the plate without the amount screen.
@MainActor
struct FoodQuickAddItemTests {

    private func meal(daysAgo: Int, _ items: [MealItemModel]) -> MealLogModel {
        let date = Date().addingTimeInterval(-Double(daysAgo) * 86_400)
        return MealLogModel(authorId: "user-1", dayKey: date.dayKey, date: date, items: items)
    }

    /// A "+" re-logs the most recent amount, in the unit it was logged in, not whichever meal
    /// happens to come first in the collection.
    @Test("Test Quick Add Repeats The Last Logged Amount")
    func testQuickAddRepeatsTheLastLoggedAmount() {
        let bread = FoodModel(name: "Bread", nutrients: NutrientMap([.calories: 250]), servingWeight: 40, portionSize: 1, portionName: "slice")
        let slice = bread.servingUnits.first { $0.name == "slice" }
        let meals = [
            meal(daysAgo: 0, [bread.mealItem(amount: 3, unit: slice)]),
            meal(daysAgo: 5, [bread.mealItem(amount: 80)])
        ]

        let item = bread.quickAddItem(lastLoggedIn: meals.reversed())

        #expect(item.amount == 3)
        #expect(item.unit == "slice")
        #expect(item.resolvedGrams == 120)
    }

    /// A never-logged food with a named portion goes on as that portion, as the amount screen
    /// opens: "1 slice", not its weight in grams.
    @Test("Test Quick Add Uses A Named Portion")
    func testQuickAddUsesANamedPortion() {
        let bread = FoodModel(name: "Bread", nutrients: NutrientMap([.calories: 250]), servingWeight: 40, portionSize: 1, portionName: "slice")

        let item = bread.quickAddItem(lastLoggedIn: [])

        #expect(item.amount == 1)
        #expect(item.unit == "slice")
        #expect(item.resolvedGrams == 40)
    }

    /// 400 g of a 150 kcal/100 g food making four servings: 150 kcal a serving.
    private func chilli() -> RecipeTemplateModel {
        RecipeTemplateModel.newRecipeTemplate(
            name: "Chilli",
            authorId: "user-1",
            ingredients: [
                RecipeIngredientModel(ingredient: FoodModel(name: "Mince", nutrients: NutrientMap([.calories: 150])), amount: 400, unit: .grams)
            ],
            servingQuantity: 4
        )
    }

    /// A recipe's "+" repeats the servings last logged, or adds one, scaled per serving either way.
    @Test("Test Recipe Quick Add Repeats The Last Servings")
    func testRecipeQuickAddRepeatsTheLastServings() {
        let recipe = chilli()
        let logged = [meal(daysAgo: 1, [recipe.mealItem(servings: 2)])]

        let again = recipe.quickAddItem(lastLoggedIn: logged)
        let first = recipe.quickAddItem(lastLoggedIn: [])

        #expect(again.amount == 2)
        #expect(again.nutrients[.calories] == 300)
        #expect(first.amount == 1)
        #expect(first.nutrients[.calories] == 150)
    }

    /// "Recent" is by when meals were eaten, newest first, each food or recipe once — not the
    /// order the collection happens to store them in — and recipes are in it too.
    @Test("Test Recent Picks Are Newest First And Include Recipes")
    func testRecentPicksAreNewestFirstAndIncludeRecipes() {
        let oats = FoodModel(ingredientId: "oats", name: "Oats")
        let milk = FoodModel(ingredientId: "milk", name: "Milk")
        let eggs = FoodModel(ingredientId: "eggs", name: "Eggs")
        let recipe = chilli()
        let meals = [
            meal(daysAgo: 0, [eggs.mealItem(amount: 100)]),
            meal(daysAgo: 3, [oats.mealItem(amount: 40), milk.mealItem(amount: 250)]),
            meal(daysAgo: 1, [oats.mealItem(amount: 40), recipe.mealItem(servings: 1)])
        ]

        let picks = meals.recentPicks(foods: [oats, milk, eggs], recipes: [recipe])

        #expect(picks.map(\.id) == ["food-eggs", "recipe-\(recipe.id)", "food-oats", "food-milk"])
    }

    /// A food never logged goes on at its default portion.
    @Test("Test Quick Add Falls Back To The Default Portion")
    func testQuickAddFallsBackToTheDefaultPortion() {
        let oats = FoodModel(name: "Oats", nutrients: NutrientMap([.calories: 380]))
        let other = FoodModel(name: "Milk").mealItem(amount: 250)

        let item = oats.quickAddItem(lastLoggedIn: [meal(daysAgo: 0, [other])])

        #expect(item.amount == oats.defaultPortionAmount)
        #expect(item.unit == "g")
    }
}

/// The picker row's second line describes the portion it names.
@MainActor
struct FoodPickerRowDetailTests {

    @Test("Test A Food Row Scales Its Figures To The Named Portion")
    func testAFoodRowScalesItsFiguresToTheNamedPortion() {
        var nutrients = NutrientMap()
        nutrients[.calories] = 884
        nutrients[.fatTotal] = 100
        let oil = FoodModel(name: "Olive Oil", nutrients: nutrients, servingWeight: 13.5, portionSize: 1, portionName: "tbsp")

        let detail = FoodLibraryPickerRowDelegate(item: oil, showMacros: false).detail

        #expect(detail == "\(Format.kcal(884 * 0.135)) · 1 tbsp")
    }

    @Test("Test A Food With No Portion Says Its Figures Are Per 100 g")
    func testAFoodWithNoPortionSaysItsFiguresArePer100g() {
        var nutrients = NutrientMap()
        nutrients[.calories] = 389
        let oats = FoodModel(name: "Oats", nutrients: nutrients, portionSize: 0.5, portionName: "cup")

        let detail = FoodLibraryPickerRowDelegate(item: oats, showMacros: false).detail

        #expect(detail == "\(Format.kcal(389)) · 100 g")
    }
}
