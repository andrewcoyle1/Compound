//
//  AmountPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Defining what one portion of a new food is.
///
/// The screen offers three mutually exclusive ways to describe a portion, and carries only the
/// fields belonging to the one chosen. Carrying a field from a branch the user did not pick would
/// define the food twice over, by weight and by serving at once.
@MainActor
struct PortionDefinitionPresenterTests {

    private final class Interactor: SpyGlobalInteractor, PortionDefinitionInteractor { }

    private final class Router: PortionDefinitionRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var foodDelegates: [FoodDefinitionDelegate] = []

        func showFoodDefinitionView(delegate: FoodDefinitionDelegate) {
            foodDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: PortionDefinitionPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: PortionDefinitionPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func delegate() -> PortionDefinitionDelegate {
        PortionDefinitionDelegate(
            name: "Oat Milk",
            brandName: "Brand",
            barcode: "5012345678900",
            image: nil,
            productFront: nil,
            nutritionPhoto: nil
        )
    }

    // MARK: - What can be moved on from

    /// A serving has to say how many of what, or the food would be defined in terms of a portion
    /// nobody described.
    @Test("Test A Serving Needs A Size And A Name")
    func testAServingNeedsASizeAndAName() {
        let screen = makeScreen()
        screen.presenter.nutritionDefinitionOption = .serving

        screen.presenter.portionName = ""
        #expect(!screen.presenter.canSave)

        screen.presenter.portionName = "glass"
        screen.presenter.portionSize = 0
        #expect(!screen.presenter.canSave)

        screen.presenter.portionSize = 1
        #expect(screen.presenter.canSave)
    }

    /// The other two options describe the food per 100g or per 100ml, which needs nothing typed.
    @Test("Test The Standard Options Need Nothing Typed")
    func testTheStandardOptionsNeedNothingTyped() {
        let screen = makeScreen()

        screen.presenter.nutritionDefinitionOption = .standardMass
        #expect(screen.presenter.canSave)

        screen.presenter.nutritionDefinitionOption = .standardVolume
        #expect(screen.presenter.canSave)
    }

    /// The guard is on the action as well as the button.
    @Test("Test An Incomplete Serving Does Not Move On")
    func testAnIncompleteServingDoesNotMoveOn() {
        let screen = makeScreen()
        screen.presenter.nutritionDefinitionOption = .serving
        screen.presenter.portionName = ""

        screen.presenter.onNextPressed(delegate: delegate())

        #expect(screen.router.foodDelegates.isEmpty)
    }

    // MARK: - Only the chosen branch's fields travel

    @Test("Test A Serving Carries Only Its Own Fields")
    func testAServingCarriesOnlyItsOwnFields() {
        let screen = makeScreen()
        screen.presenter.nutritionDefinitionOption = .serving
        screen.presenter.servingWeight = 250
        screen.presenter.portionSize = 1
        screen.presenter.portionName = "glass"
        // Left over from a branch the user looked at and moved away from.
        screen.presenter.portionWeight = 999
        screen.presenter.portionVolume = 888

        screen.presenter.onNextPressed(delegate: delegate())

        let passed = screen.router.foodDelegates.first
        #expect(passed?.servingWeight == 250)
        #expect(passed?.portionSize == 1)
        #expect(passed?.portionName == "glass")
        #expect(passed?.portionWeight == nil)
        #expect(passed?.portionVolume == nil)
    }

    @Test("Test A Standard Mass Carries Only Its Own Fields")
    func testAStandardMassCarriesOnlyItsOwnFields() {
        let screen = makeScreen()
        screen.presenter.nutritionDefinitionOption = .standardMass
        screen.presenter.portionWeight = 30
        screen.presenter.weightPortionSize = 1
        screen.presenter.weightPortionName = "scoop"
        screen.presenter.servingWeight = 999

        screen.presenter.onNextPressed(delegate: delegate())

        let passed = screen.router.foodDelegates.first
        #expect(passed?.portionWeight == 30)
        #expect(passed?.weightPortionSize == 1)
        #expect(passed?.weightPortionName == "scoop")
        #expect(passed?.servingWeight == nil)
        #expect(passed?.portionVolume == nil)
    }

    @Test("Test A Standard Volume Carries Only Its Own Fields")
    func testAStandardVolumeCarriesOnlyItsOwnFields() {
        let screen = makeScreen()
        screen.presenter.nutritionDefinitionOption = .standardVolume
        screen.presenter.portionVolume = 330
        screen.presenter.volumePortionSize = 1
        screen.presenter.volumePortionName = "can"
        screen.presenter.portionWeight = 999

        screen.presenter.onNextPressed(delegate: delegate())

        let passed = screen.router.foodDelegates.first
        #expect(passed?.portionVolume == 330)
        #expect(passed?.volumePortionSize == 1)
        #expect(passed?.volumePortionName == "can")
        #expect(passed?.portionWeight == nil)
        #expect(passed?.servingWeight == nil)
    }

    /// Everything from the earlier steps rides along regardless of which branch was taken.
    @Test("Test The Earlier Steps Fields Survive Every Branch")
    func testTheEarlierStepsFieldsSurviveEveryBranch() {
        for option in [NutritionDefinitionOption.serving, .standardMass, .standardVolume] {
            let screen = makeScreen()
            screen.presenter.nutritionDefinitionOption = option

            screen.presenter.onNextPressed(delegate: delegate())

            let passed = screen.router.foodDelegates.first
            #expect(passed?.name == "Oat Milk")
            #expect(passed?.brandName == "Brand")
            #expect(passed?.barcode == "5012345678900")
            #expect(passed?.nutritionDefinitionOption == option)
        }
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: delegate())

        #expect(screen.interactor.trackedScreenEventNames == ["PortionDefinitionView_Appear"])
    }
}

/// Choosing how much of a food is being logged — both when adding one and when editing an amount
/// already logged.
///
/// The two modes look identical on screen and scale completely differently underneath. Adding
/// works from a food's per-100g figures, so the scale is the amount over a hundred. Editing works
/// from figures already scaled to the old amount, which the delegate divides back down to one
/// unit, so the scale is the amount itself. Swapping the two would be out by a hundredfold.
@MainActor
struct MealItemAmountPresenterTests {

    private final class Interactor: SpyGlobalInteractor, MealItemAmountViewInteractor { }

    private final class Router: MealItemAmountViewRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    /// Main-actor isolated so it is `Sendable` for the confirm closure.
    @MainActor
    private final class ItemBox {
        var item: MealItemModel?
    }

    private func food(
        name: String = "Oats",
        caloriesPer100g: Double = 380,
        method: MeasurementMethod = .weight
    ) -> FoodModel {
        FoodModel(
            ingredientId: "food-1",
            name: name,
            measurementMethod: method,
            nutrients: NutrientMap([.calories: caloriesPer100g, .protein: 13])
        )
    }

    /// An item already logged: 50g of the food above, so its stored figures are half the per-100g.
    private func loggedItem(amount: Double = 50, calories: Double = 190) -> MealItemModel {
        MealItemModel(
            itemId: "item-1",
            sourceType: .ingredient,
            sourceId: "food-1",
            displayName: "Oats",
            amount: amount,
            unit: "g",
            resolvedGrams: amount,
            nutrients: NutrientMap([.calories: calories])
        )
    }

    private struct Screen {
        let presenter: MealItemAmountViewPresenter
        let box: ItemBox
        let delegate: MealItemAmountViewDelegate
        let interactor: Interactor
    }

    private func makeScreen(mode: MealItemAmountViewMode) -> Screen {
        let box = ItemBox()
        let delegate = MealItemAmountViewDelegate(mode: mode, onConfirm: { box.item = $0 })
        let interactor = Interactor()
        return Screen(
            presenter: MealItemAmountViewPresenter(
                interactor: interactor,
                router: Router(),
                delegate: delegate
            ),
            box: box,
            delegate: delegate,
            interactor: interactor
        )
    }

    @Test("Test Confirming Plays A Success Haptic")
    func testConfirmingPlaysASuccessHaptic() {
        let screen = makeScreen(mode: .addFood(food()))

        screen.presenter.onConfirmPressed(delegate: screen.delegate)

        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    /// Adding a food to the plate and correcting a logged one are different jobs, so the button
    /// says which. "Add" rather than "Log": the meal itself is logged later, from Add Meal.
    @Test("Test Adding Adds And Editing Saves")
    func testAddingAddsAndEditingSaves() {
        let adding = MealItemAmountViewDelegate(mode: .addFood(food()), onConfirm: { _ in })
        let editing = MealItemAmountViewDelegate(mode: .editItem(loggedItem()), onConfirm: { _ in })

        #expect(adding.confirmTitle == String(localized: "Add"))
        #expect(editing.confirmTitle == String(localized: "Save"))
    }

    // MARK: - Adding a food

    /// `Double("nan")` and `Double("inf")` both parse, so a text field is a few letters away from
    /// a figure that is not a number — and this screen writes both the amount and the nutrients
    /// scaled from it straight onto the meal item, where the meal-log rows later print them
    /// through `Int(_:)`. There was no floor here at all to be fooled by NaN; the parse simply
    /// took whatever came back.
    @Test("Test An Amount That Is Not A Number Confirms Finite Figures")
    func testAnAmountThatIsNotANumberConfirmsFiniteFigures() {
        for typed in ["nan", "inf", "-inf", "1e400"] {
            let screen = makeScreen(mode: .addFood(food()))
            screen.presenter.amountText = typed

            #expect(screen.presenter.calories.isFinite, "\(typed) should not survive as an amount")

            screen.presenter.onConfirmPressed(delegate: screen.delegate)

            #expect(screen.box.item?.amount.isFinite == true)
            #expect(screen.box.item?.nutrients.allSatisfy { $0.value.isFinite } == true)
        }
    }

    /// Per-100g figures against a typed amount: 200g of a 380/100g food is 760.
    @Test("Test Adding Scales From Per 100g")
    func testAddingScalesFromPer100g() {
        let screen = makeScreen(mode: .addFood(food()))
        let presenter = screen.presenter
        presenter.amountText = "200"

        #expect(presenter.calories == 760)
        #expect(presenter.protein == 26)
    }

    @Test("Test Adding Stores The Scaled Nutrients")
    func testAddingStoresTheScaledNutrients() {
        let screen = makeScreen(mode: .addFood(food()))
        let presenter = screen.presenter
        let box = screen.box
        let delegate = screen.delegate
        presenter.amountText = "50"

        presenter.onConfirmPressed(delegate: delegate)

        #expect(box.item?.nutrients[.calories] == 190)
        #expect(box.item?.amount == 50)
    }

    /// A weight-measured food resolves to grams and nothing else; a drink to millilitres. Setting
    /// both, or the wrong one, would put a drink on the plate as a solid.
    @Test("Test A Weighed Food Resolves To Grams Only")
    func testAWeighedFoodResolvesToGramsOnly() {
        let screen = makeScreen(mode: .addFood(food(method: .weight)))
        let presenter = screen.presenter
        let box = screen.box
        let delegate = screen.delegate
        presenter.amountText = "50"

        presenter.onConfirmPressed(delegate: delegate)

        #expect(box.item?.resolvedGrams == 50)
        #expect(box.item?.resolvedMilliliters == nil)
    }

    @Test("Test A Drink Resolves To Millilitres Only")
    func testADrinkResolvesToMillilitresOnly() {
        let screen = makeScreen(mode: .addFood(food(method: .volume)))
        let presenter = screen.presenter
        let box = screen.box
        let delegate = screen.delegate
        presenter.amountText = "250"

        presenter.onConfirmPressed(delegate: delegate)

        #expect(box.item?.resolvedMilliliters == 250)
        #expect(box.item?.resolvedGrams == nil)
    }

    @Test("Test An Added Item Points At The Food It Came From")
    func testAnAddedItemPointsAtTheFoodItCameFrom() {
        let screen = makeScreen(mode: .addFood(food()))
        let presenter = screen.presenter
        let box = screen.box
        let delegate = screen.delegate

        presenter.onConfirmPressed(delegate: delegate)

        #expect(box.item?.sourceType == .ingredient)
        #expect(box.item?.sourceId == "food-1")
        #expect(box.item?.displayName == "Oats")
    }

    // MARK: - Editing an amount

    /// The delegate divides the stored figures back to one unit, so the presenter multiplies by
    /// the amount rather than by the amount over a hundred. Doubling 50g to 100g doubles the
    /// calories — it does not multiply them by a hundred.
    @Test("Test Editing Scales From The Stored Amount")
    func testEditingScalesFromTheStoredAmount() {
        let screen = makeScreen(mode: .editItem(loggedItem(amount: 50, calories: 190)))
        let presenter = screen.presenter
        presenter.amountText = "100"

        #expect(presenter.calories == 380)
    }

    @Test("Test Editing Keeps The Item It Is Editing")
    func testEditingKeepsTheItemItIsEditing() {
        let screen = makeScreen(mode: .editItem(loggedItem()))
        let presenter = screen.presenter
        let box = screen.box
        let delegate = screen.delegate
        presenter.amountText = "75"

        presenter.onConfirmPressed(delegate: delegate)

        // The same row, changed — not a new one, which would leave the old amount logged too.
        #expect(box.item?.itemId == "item-1")
        #expect(box.item?.displayName == "Oats")
        #expect(box.item?.unit == "g")
        #expect(box.item?.amount == 75)
    }

    /// The resolved weight has to move with the amount, or the row would read 75g while still
    /// resolving to the 50g it was.
    @Test("Test Editing Moves The Resolved Weight With The Amount")
    func testEditingMovesTheResolvedWeightWithTheAmount() {
        let screen = makeScreen(mode: .editItem(loggedItem(amount: 50)))
        let presenter = screen.presenter
        let box = screen.box
        let delegate = screen.delegate
        presenter.amountText = "100"

        presenter.onConfirmPressed(delegate: delegate)

        #expect(box.item?.resolvedGrams == 100)
    }

    /// An item logged with no amount cannot be divided back to a unit figure, so there is nothing
    /// to scale up from and its nutrients drop out entirely rather than becoming infinity.
    ///
    /// Absent, not zero — which is the right call. A zero would claim this row contributes no
    /// calories, while absent says only that nothing is known, and the row still shows the amount
    /// the user typed so it can be corrected.
    @Test("Test Editing An Item With No Amount Does Not Blow Up")
    func testEditingAnItemWithNoAmountDoesNotBlowUp() {
        let screen = makeScreen(mode: .editItem(loggedItem(amount: 0, calories: 100)))
        let presenter = screen.presenter
        let box = screen.box
        let delegate = screen.delegate
        presenter.amountText = "50"

        presenter.onConfirmPressed(delegate: delegate)

        #expect(box.item?.nutrients[.calories] == nil)
        #expect(box.item?.amount == 50)
        #expect(box.item?.resolvedGrams == 0)
    }

    // MARK: - What is typed

    /// The field is free text, so anything unparseable reads as zero rather than crashing or
    /// carrying the last good value.
    @Test("Test Unparseable Text Reads As Zero")
    func testUnparseableTextReadsAsZero() {
        let screen = makeScreen(mode: .addFood(food()))
        let presenter = screen.presenter
        presenter.amountText = "abc"

        #expect(presenter.amountValue == 0)
        #expect(presenter.calories == 0)
    }

    /// Adding opens on the food's own portion when it has one, rather than a bare 100g.
    @Test("Test Adding Opens On The Foods Own Portion")
    func testAddingOpensOnTheFoodsOwnPortion() {
        let portioned = FoodModel(name: "Oat Milk", nutrients: NutrientMap(), servingWeight: 250)
        let screen = makeScreen(mode: .addFood(portioned))
        let presenter = screen.presenter

        #expect(presenter.amountText == "250")
    }

    @Test("Test Editing Opens On The Amount Already Logged")
    func testEditingOpensOnTheAmountAlreadyLogged() {
        let screen = makeScreen(mode: .editItem(loggedItem(amount: 75)))
        let presenter = screen.presenter

        #expect(presenter.amountText == "75")
    }
}

/// The two ingredient-amount screens: one adds a food to the plate, the other adds it to a recipe.
/// Both scale from per-100g figures and both must pick the right unit for the food.
///
/// Named for the ingredient rather than the recipe — `RecipeAmountPresenterTests` covers the
/// screen that logs servings of a finished recipe.
@MainActor
struct IngredientAmountPresenterTests {

    private final class IngredientInteractor: SpyGlobalInteractor, IngredientAmountInteractor { }
    /// Declared unguarded: the test target builds without `-DDEV`, so guarding it the way the
    /// router does would leave the protocol unsatisfied.
    private final class IngredientRouter: IngredientAmountRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showDevSettingsView() { }
    }

    private final class RecipeInteractor: SpyGlobalInteractor, RecipeIngredientAmountInteractor { }
    private final class RecipeRouter: RecipeIngredientAmountRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    @MainActor
    private final class ItemBox {
        var item: MealItemModel?
        var ingredient: RecipeIngredientModel?
    }

    private func food(method: MeasurementMethod = .weight) -> FoodModel {
        FoodModel(
            ingredientId: "food-1",
            name: "Oats",
            measurementMethod: method,
            nutrients: NutrientMap([.calories: 380, .protein: 13])
        )
    }

    private func ingredientPresenter() -> IngredientAmountPresenter {
        IngredientAmountPresenter(interactor: IngredientInteractor(), router: IngredientRouter())
    }

    private func recipePresenter() -> RecipeIngredientAmountPresenter {
        RecipeIngredientAmountPresenter(interactor: RecipeInteractor(), router: RecipeRouter())
    }

    // MARK: - Adding an ingredient to the plate

    @Test("Test Logging An Ingredient Or Adding It To A Recipe Plays A Success Haptic")
    func testLoggingAnIngredientOrAddingItToARecipePlaysASuccessHaptic() {
        let ingredientInteractor = IngredientInteractor()
        IngredientAmountPresenter(interactor: ingredientInteractor, router: IngredientRouter())
            .add(ingredient: food()) { _ in }
        #expect(ingredientInteractor.playedHaptics.map { "\($0)" } == ["success"])

        let recipeInteractor = RecipeInteractor()
        RecipeIngredientAmountPresenter(interactor: recipeInteractor, router: RecipeRouter())
            .confirm(delegate: RecipeIngredientAmountDelegate(food: food(), onConfirm: { _ in }))
        #expect(recipeInteractor.playedHaptics.map { "\($0)" } == ["success"])
    }

    @Test("Test An Ingredient Amount Scales From Per 100g")
    func testAnIngredientAmountScalesFromPer100g() {
        let presenter = ingredientPresenter()
        presenter.amountText = "50"

        #expect(presenter.calories(ingredient: food()) == 190)
        #expect(presenter.protein(ingredient: food()) == 6.5)
    }

    @Test("Test The Ingredient Unit Follows The Foods Measurement")
    func testTheIngredientUnitFollowsTheFoodsMeasurement() {
        let presenter = ingredientPresenter()

        #expect(presenter.unitLabel(ingredient: food(method: .weight)) == "g")
        #expect(presenter.unitLabel(ingredient: food(method: .volume)) == "ml")
    }

    @Test("Test Adding An Ingredient Builds A Scaled Item")
    func testAddingAnIngredientBuildsAScaledItem() {
        let presenter = ingredientPresenter()
        presenter.amountText = "200"
        let box = ItemBox()

        presenter.add(ingredient: food()) { box.item = $0 }

        #expect(box.item?.nutrients[.calories] == 760)
        #expect(box.item?.amount == 200)
        #expect(box.item?.resolvedGrams == 200)
        #expect(box.item?.resolvedMilliliters == nil)
    }

    /// A negative amount would otherwise subtract food from the day.
    @Test("Test A Negative Amount Scales To Nothing")
    func testANegativeAmountScalesToNothing() {
        let presenter = ingredientPresenter()
        presenter.amountText = "-50"

        #expect(presenter.scale == 0)
        #expect(presenter.calories(ingredient: food()) == 0)
    }

    /// A food with no figure for a nutrient has none after scaling either — zero would assert the
    /// food contains none of it.
    @Test("Test A Missing Nutrient Stays Missing After Scaling")
    func testAMissingNutrientStaysMissingAfterScaling() {
        let presenter = ingredientPresenter()
        let bare = FoodModel(name: "Water", nutrients: NutrientMap())

        #expect(presenter.calories(ingredient: bare) == nil)
    }

    // MARK: - Adding an ingredient to a recipe

    @Test("Test A Recipe Ingredient Takes The Amount And Unit Chosen")
    func testARecipeIngredientTakesTheAmountAndUnitChosen() {
        let presenter = recipePresenter()
        presenter.amountText = "250"
        let box = ItemBox()
        let delegate = RecipeIngredientAmountDelegate(food: food(), onConfirm: { box.ingredient = $0 })

        presenter.confirm(delegate: delegate)

        #expect(box.ingredient?.amount == 250)
        #expect(box.ingredient?.unit == .grams)
        #expect(box.ingredient?.ingredient.ingredientId == "food-1")
    }

    /// A liquid goes into the recipe in millilitres, which is what the recipe's own scaling later
    /// reads to decide how to convert it.
    @Test("Test A Liquid Ingredient Goes In As Millilitres")
    func testALiquidIngredientGoesInAsMillilitres() {
        let presenter = recipePresenter()
        presenter.amountText = "500"
        let box = ItemBox()
        let delegate = RecipeIngredientAmountDelegate(
            food: food(method: .volume),
            onConfirm: { box.ingredient = $0 }
        )

        presenter.confirm(delegate: delegate)

        #expect(box.ingredient?.unit == .milliliters)
    }

    @Test("Test The Recipe Amount Preview Scales From Per 100g")
    func testTheRecipeAmountPreviewScalesFromPer100g() {
        let presenter = recipePresenter()
        presenter.amountText = "50"

        #expect(presenter.calories(food: food()) == 190)
    }

    // MARK: - Amounts that are not numbers

    /// The unparseable text that does parse. `Double("nan")`, `Double("inf")` and `Double("-inf")`
    /// all succeed, and `Double("1e400")` overflows to infinity, so a text field is a few letters
    /// away from a value that is not a number. The `max(amountValue, 0)` that used to floor
    /// `scale` caught none of them: `max` is `y >= x ? y : x`, every comparison against NaN is
    /// false so the NaN came back instead of the floor, and an infinity was above the floor
    /// already. Both screens then print `calories * scale` through `Int(_:)` from the view body,
    /// which traps rather than showing a wrong number.
    @Test("Test An Ingredient Amount That Is Not A Number Scales To Nothing")
    func testAnIngredientAmountThatIsNotANumberScalesToNothing() {
        for typed in ["nan", "NaN", "inf", "-inf", "infinity", "1e400"] {
            let presenter = ingredientPresenter()
            presenter.amountText = typed

            #expect(presenter.scale == 0, "\(typed) should not survive as an amount")
            #expect(presenter.calories(ingredient: food()) == 0)
        }
    }

    @Test("Test A Recipe Ingredient Amount That Is Not A Number Scales To Nothing")
    func testARecipeIngredientAmountThatIsNotANumberScalesToNothing() {
        for typed in ["nan", "inf", "-inf", "1e400"] {
            let presenter = recipePresenter()
            presenter.amountText = typed

            #expect(presenter.scale == 0, "\(typed) should not survive as an amount")
            #expect(presenter.calories(food: food()) == 0)
        }
    }

    /// What is stored matters as much as what is drawn: the amount goes onto the recipe, and a
    /// non-finite one would come back out of the document at every later read.
    @Test("Test A Recipe Ingredient Is Stored With A Finite Amount")
    func testARecipeIngredientIsStoredWithAFiniteAmount() {
        for typed in ["nan", "inf", "1e400"] {
            let presenter = recipePresenter()
            presenter.amountText = typed
            let box = ItemBox()
            let delegate = RecipeIngredientAmountDelegate(food: food(), onConfirm: { box.ingredient = $0 })

            presenter.confirm(delegate: delegate)

            #expect(box.ingredient?.amount.isFinite == true)
        }
    }

    /// The same for the plate: a NaN calorie figure logged here is printed through `Int(_:)` by
    /// the meal-log rows long after the screen that made it has gone.
    @Test("Test An Ingredient Is Logged With Finite Nutrients")
    func testAnIngredientIsLoggedWithFiniteNutrients() {
        for typed in ["nan", "inf", "1e400"] {
            let presenter = ingredientPresenter()
            presenter.amountText = typed
            let box = ItemBox()

            presenter.add(ingredient: food()) { box.item = $0 }

            #expect(box.item?.amount.isFinite == true)
            #expect(box.item?.nutrients.allSatisfy { $0.value.isFinite } == true)
        }
    }
}
