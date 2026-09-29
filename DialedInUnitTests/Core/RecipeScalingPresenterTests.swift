//
//  RecipeScalingPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 25/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// The servings stepper on a recipe's own screen.
@MainActor
struct RecipeDetailServingsPresenterTests {

    private final class Interactor: RecipeDetailInteractor {
        var currentUser: UserModel?
        func isFavouriteRecipe(id: String) -> Bool { false }
        func setFavouriteRecipe(id: String, isFavourite: Bool) async throws { }
        func deleteRecipeTemplate(id: String) async throws { }
    }

    /// `showDevSettingsView()` unguarded — the test target builds without `-DDEV`.
    private final class Router: RecipeDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showDevSettingsView() { }
        func showStartRecipeView(delegate: RecipeStartDelegate) { }
    }

    private func presenter() -> RecipeDetailPresenter {
        RecipeDetailPresenter(interactor: Interactor(), router: Router())
    }

    /// Makes 4 servings from 400g of a 150kcal/100g mince and 100g of a 20g-protein bean.
    private func recipe() -> RecipeTemplateModel {
        RecipeTemplateModel.newRecipeTemplate(
            name: "Chilli",
            authorId: "user-1",
            ingredients: [
                RecipeIngredientModel(
                    ingredient: FoodModel(name: "Mince", nutrients: NutrientMap([.calories: 150])),
                    amount: 400,
                    unit: .grams
                ),
                RecipeIngredientModel(
                    ingredient: FoodModel(name: "Beans", nutrients: NutrientMap([.protein: 20])),
                    amount: 100,
                    unit: .grams
                )
            ],
            servingQuantity: 4
        )
    }

    @Test("Test The Stepper Starts On The Recipe As Written")
    func testTheStepperStartsOnTheRecipeAsWritten() {
        let chilli = recipe()
        let presenter = presenter()

        #expect(presenter.servings(recipe: chilli) == 4)
        #expect(presenter.scaledAmount(chilli.ingredients[0], recipe: chilli) == 400)
        #expect(presenter.scaledNutrients(recipe: chilli)[.calories] == 600)
    }

    @Test("Test Stepping Scales Every Ingredient And The Nutrition")
    func testSteppingScalesEveryIngredientAndTheNutrition() {
        let chilli = recipe()
        let presenter = presenter()

        presenter.onServingsChanged(6)

        #expect(presenter.scaledAmount(chilli.ingredients[0], recipe: chilli) == 600)
        #expect(presenter.scaledAmount(chilli.ingredients[1], recipe: chilli) == 150)
        #expect(presenter.scaledNutrients(recipe: chilli)[.calories] == 900)
        #expect(presenter.scaledNutrients(recipe: chilli)[.protein] == 30)
    }

    /// Thirds of 100g print to one decimal place rather than a tail of threes.
    @Test("Test A Fractional Serving Rounds The Amounts")
    func testAFractionalServingRoundsTheAmounts() {
        let chilli = recipe()
        let presenter = presenter()

        presenter.onServingsChanged(1.5)

        #expect(presenter.servings(recipe: chilli) == 1.5)
        #expect(presenter.scaledAmount(chilli.ingredients[1], recipe: chilli) == 37.5)
    }

    @Test("Test Servings Cannot Step Below Half Or To Something Not A Number")
    func testServingsCannotStepBelowHalfOrToSomethingNotANumber() {
        let chilli = recipe()
        let presenter = presenter()

        presenter.onServingsChanged(0)
        #expect(presenter.servings(recipe: chilli) == 0.5)

        presenter.onServingsChanged(.nan)
        #expect(presenter.servings(recipe: chilli) == 0.5)
    }
}

/// The unit picker on the two add-food sheets.
@MainActor
struct ServingUnitPickerPresenterTests {

    private final class IngredientInteractor: SpyGlobalInteractor, IngredientAmountInteractor { }
    private final class IngredientRouter: IngredientAmountRouter {
        let router: AnyRouter = TestRouting.anyRouter
        func showDevSettingsView() { }
    }

    private final class MealItemInteractor: SpyGlobalInteractor, MealItemAmountViewInteractor { }
    private final class MealItemRouter: MealItemAmountViewRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    @MainActor
    private final class ItemBox {
        var item: MealItemModel?
    }

    private let slice = ServingUnit(name: "slice", grams: 40)

    /// 250kcal per 100g, one slice being 40g.
    private func bread() -> FoodModel {
        FoodModel(
            ingredientId: "bread",
            name: "Bread",
            nutrients: NutrientMap([.calories: 250]),
            servingWeight: 40,
            portionSize: 1,
            portionName: "slice"
        )
    }

    @Test("Test Picking A Unit Counts One Of It")
    func testPickingAUnitCountsOneOfIt() {
        let presenter = IngredientAmountPresenter(interactor: IngredientInteractor(), router: IngredientRouter())

        presenter.selectedUnit = bread().servingUnits.first

        #expect(presenter.selectedUnit == slice)
        #expect(presenter.amountText == "1")
        #expect(presenter.unitLabel(ingredient: bread()) == "slice")
        #expect(presenter.calories(ingredient: bread()) == 100)
    }

    @Test("Test Going Back To Grams Keeps The Same Quantity")
    func testGoingBackToGramsKeepsTheSameQuantity() {
        let presenter = IngredientAmountPresenter(interactor: IngredientInteractor(), router: IngredientRouter())
        presenter.selectedUnit = slice
        presenter.amountText = "2.5"

        presenter.selectedUnit = nil

        #expect(presenter.amountText == "100")
        #expect(presenter.unitLabel(ingredient: bread()) == "g")
    }

    @Test("Test Logging In A Unit Stores The Unit And Its Grams")
    func testLoggingInAUnitStoresTheUnitAndItsGrams() {
        let presenter = IngredientAmountPresenter(interactor: IngredientInteractor(), router: IngredientRouter())
        presenter.selectedUnit = slice
        presenter.amountText = "3"
        let box = ItemBox()

        presenter.add(ingredient: bread()) { box.item = $0 }

        #expect(box.item?.amount == 3)
        #expect(box.item?.unit == "slice")
        #expect(box.item?.resolvedGrams == 120)
        #expect(box.item?.nutrients[.calories] == 300)
    }

    @Test("Test The Meal Item Sheet Logs In The Unit Picked")
    func testTheMealItemSheetLogsInTheUnitPicked() {
        let box = ItemBox()
        let delegate = MealItemAmountViewDelegate(mode: .addFood(bread()), onConfirm: { box.item = $0 })
        let presenter = MealItemAmountViewPresenter(interactor: MealItemInteractor(), router: MealItemRouter(), delegate: delegate)

        presenter.selectedUnit = slice
        presenter.amountText = "2"

        #expect(presenter.unitLabel(delegate: delegate) == "slice")
        #expect(presenter.calories == 200)

        presenter.onConfirmPressed(delegate: delegate)

        #expect(box.item?.unit == "slice")
        #expect(box.item?.resolvedGrams == 80)
        #expect(box.item?.nutrients[.calories] == 200)
    }
}
