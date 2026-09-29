//
//  NutritionScalingTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 25/09/2026.
//

import Testing
import Foundation
@testable import DialedIn

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
