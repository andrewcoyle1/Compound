//
//  RecipeFlowPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Logging a recipe: how many servings of it were eaten.
///
/// This is the second place that turns a recipe into a meal item, and it has to agree with the
/// first. A recipe's ingredients describe the whole dish, so one serving is the total divided
/// across the servings it makes — and then multiplied by however many were actually eaten.
@MainActor
struct RecipeAmountPresenterTests {

    private final class Interactor: RecipeAmountInteractor { }

    /// `showDevSettingsView()` unguarded — the test target builds without `-DDEV`.
    private final class Router: RecipeAmountRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showDevSettingsView() { }
    }

    @MainActor
    private final class ItemBox {
        var item: MealItemModel?
    }

    private func presenter() -> RecipeAmountPresenter {
        RecipeAmountPresenter(interactor: Interactor(), router: Router())
    }

    /// Carries a calorie figure and nothing else, so "a nutrient no ingredient has" is genuinely
    /// absent rather than present as zero.
    private func food(calories: Double) -> FoodModel {
        FoodModel(name: "Mince", nutrients: NutrientMap([.calories: calories]))
    }

    /// A recipe making `servings` from 400g of a 150kcal/100g food: 600kcal in the pot.
    private func recipe(servings: Double, grams: Double = 400, calories: Double = 150) -> RecipeTemplateModel {
        RecipeTemplateModel.newRecipeTemplate(
            name: "Chilli",
            authorId: "user-1",
            ingredients: [
                RecipeIngredientModel(ingredient: food(calories: calories), amount: grams, unit: .grams)
            ],
            servingQuantity: servings
        )
    }

    // MARK: - One serving is one serving

    /// The figures shown are labelled "per serving", so they are the pot divided by the servings
    /// it makes — not the whole pot. This read four times high for a four-serving dish.
    @Test("Test The Preview Is Per Serving Not The Whole Recipe")
    func testThePreviewIsPerServingNotTheWholeRecipe() {
        let presenter = presenter()

        #expect(presenter.baseCalories(recipe: recipe(servings: 4)) == 150)
    }

    /// The same division has to reach what is logged, or the preview and the log disagree.
    @Test("Test Logging One Serving Logs One Serving")
    func testLoggingOneServingLogsOneServing() {
        let presenter = presenter()
        presenter.servingsText = "1"
        let box = ItemBox()

        presenter.add(recipe: recipe(servings: 4)) { box.item = $0 }

        #expect(box.item?.nutrients[.calories] == 150)
    }

    @Test("Test Logging Two Servings Logs Twice As Much")
    func testLoggingTwoServingsLogsTwiceAsMuch() {
        let presenter = presenter()
        presenter.servingsText = "2"
        let box = ItemBox()

        presenter.add(recipe: recipe(servings: 4)) { box.item = $0 }

        #expect(box.item?.nutrients[.calories] == 300)
    }

    /// A single-serving recipe is the whole pot, which is the case where the old arithmetic
    /// happened to be right.
    @Test("Test A Single Serving Recipe Logs The Whole Recipe")
    func testASingleServingRecipeLogsTheWholeRecipe() {
        let presenter = presenter()
        presenter.servingsText = "1"
        let box = ItemBox()

        presenter.add(recipe: recipe(servings: 1)) { box.item = $0 }

        #expect(box.item?.nutrients[.calories] == 600)
    }

    /// A recipe saved claiming no servings would divide by zero, so the divisor floors at one and
    /// it reads as a single serving.
    @Test("Test A Recipe Claiming No Servings Does Not Divide By Zero")
    func testARecipeClaimingNoServingsDoesNotDivideByZero() {
        let presenter = presenter()
        presenter.servingsText = "1"
        let box = ItemBox()

        presenter.add(recipe: recipe(servings: 0)) { box.item = $0 }

        #expect(box.item?.nutrients[.calories] == 600)
    }

    /// Both places that turn a recipe into a meal item must produce the same figures, or logging
    /// the same dish two ways gives two answers.
    @Test("Test It Agrees With The Recipe Builders Own Serving")
    func testItAgreesWithTheRecipeBuildersOwnServing() {
        let presenter = presenter()
        presenter.servingsText = "1"
        let box = ItemBox()
        let dish = recipe(servings: 4)

        presenter.add(recipe: dish) { box.item = $0 }

        // The builder's create-and-add divides the same total by the same servings.
        let potTotal = 600.0
        #expect(box.item?.nutrients[.calories] == potTotal / dish.servingQuantity)
    }

    // MARK: - What is typed

    @Test("Test Servings Reads As Zero When Unparseable")
    func testServingsReadsAsZeroWhenUnparseable() {
        let presenter = presenter()
        presenter.servingsText = "abc"

        #expect(presenter.servings == 0)
    }

    /// A negative serving count would subtract a meal from the day.
    @Test("Test A Negative Serving Count Floors At Zero")
    func testANegativeServingCountFloorsAtZero() {
        let presenter = presenter()
        presenter.servingsText = "-2"

        #expect(presenter.servings == 0)
    }

    /// `Double`'s string initialiser parses "nan", "inf" and "-inf" literally, and "1e400"
    /// overflows to infinity, so a text field is three letters away from a number that is not a
    /// number. `max(parsed, 0)` filtered none of them — `max` is `y >= x ? y : x` and every
    /// comparison against NaN is false, so the NaN came back instead of the floor, and an
    /// infinity was above the floor already.
    @Test("Test A Serving Count That Is Not A Number Reads As Zero")
    func testAServingCountThatIsNotANumberReadsAsZero() {
        let presenter = presenter()

        for typed in ["nan", "NaN", "inf", "-inf", "infinity", "1e400"] {
            presenter.servingsText = typed
            #expect(presenter.servings == 0, "\(typed) should not survive as a serving count")
        }
    }

    /// The reason the parse is guarded at all. `servings` multiplies into every nutrient logged
    /// for the meal, and those are both written to the meal document and printed through `Int(_:)`
    /// by the meal-log rows — a trap, not a wrong number.
    @Test("Test Nutrients Logged From A Serving Count That Is Not A Number Are Finite")
    func testNutrientsLoggedFromAServingCountThatIsNotANumberAreFinite() {
        for typed in ["nan", "inf", "-inf", "1e400"] {
            let presenter = presenter()
            presenter.servingsText = typed
            let box = ItemBox()

            presenter.add(recipe: recipe(servings: 4)) { box.item = $0 }

            let item = box.item
            #expect(item?.amount.isFinite == true)
            #expect(item?.nutrients.allSatisfy { $0.value.isFinite } == true)
        }
    }

    /// A nutrient no ingredient carries a figure for has none after aggregation either.
    @Test("Test A Nutrient No Ingredient Has Stays Absent")
    func testANutrientNoIngredientHasStaysAbsent() {
        let presenter = presenter()

        #expect(presenter.baseProtein(recipe: recipe(servings: 4)) == nil)
    }

    @Test("Test The Item Points At The Recipe As One Serving Unit")
    func testTheItemPointsAtTheRecipeAsOneServingUnit() {
        let presenter = presenter()
        presenter.servingsText = "2"
        let box = ItemBox()
        let dish = recipe(servings: 4)

        presenter.add(recipe: dish) { box.item = $0 }

        #expect(box.item?.sourceType == .recipe)
        #expect(box.item?.sourceId == dish.recipeId)
        #expect(box.item?.amount == 2)
        #expect(box.item?.unit == "serving")
        #expect(box.item?.resolvedGrams == nil)
    }
}

/// Starting a recipe: the name, servings and ingredients, before the method.
@MainActor
struct CreateRecipePresenterTests {

    private final class Interactor: SpyGlobalInteractor, CreateRecipeInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
    }

    private final class Router: CreateRecipeRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var preparationDelegates: [RecipePreparationDelegate] = []
        private(set) var builderDelegates: [IngredientListBuilderDelegate] = []
        func showDevSettingsView() { }

        func showIngredientListBuilderView(delegate: IngredientListBuilderDelegate) {
            builderDelegates.append(delegate)
        }

        func showRecipePreparationView(delegate: RecipePreparationDelegate) {
            preparationDelegates.append(delegate)
        }

    }

    private struct Screen {
        let presenter: CreateRecipePresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        let router = Router()
        return Screen(
            presenter: CreateRecipePresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func ingredient(_ name: String, amount: Double = 100) -> RecipeIngredientModel {
        RecipeIngredientModel(
            ingredient: FoodModel(ingredientId: name, name: name),
            amount: amount,
            unit: .grams
        )
    }

    @Test("Test A Recipe Cannot Be Saved Without A Name")
    func testARecipeCannotBeSavedWithoutAName() {
        let screen = makeScreen()
        screen.presenter.recipeName = "   "

        #expect(!screen.presenter.canSave)
    }

    /// Servings are what every figure on the recipe is divided by, so moving on without one would
    /// leave the dish undividable.
    ///
    /// The screen does say so, but through `showSimpleAlert`, which `CreateRecipeRouter` does not
    /// restate as a requirement — so it dispatches statically to the `GlobalRouter` extension and
    /// never reaches the double. What can be asserted, and is the half that matters, is that the
    /// step is not taken.
    @Test("Test Moving On Without Servings Goes Nowhere")
    func testMovingOnWithoutServingsGoesNowhere() {
        let screen = makeScreen()
        screen.presenter.recipeName = "Chilli"

        screen.presenter.onNextPressed()

        #expect(screen.router.preparationDelegates.isEmpty)
    }

    @Test("Test The Recipe Details Reach The Method Step")
    func testTheRecipeDetailsReachTheMethodStep() {
        let screen = makeScreen()
        screen.presenter.recipeName = "chilli con carne"
        screen.presenter.servingQuantity = 4
        screen.presenter.recipeTotalWeight = 1200
        screen.presenter.ingredients = [ingredient("Mince")]

        screen.presenter.onNextPressed()

        let passed = screen.router.preparationDelegates.first
        #expect(passed?.servingQuantity == 4)
        #expect(passed?.recipeTotalWeight == 1200)
        #expect(passed?.ingredients.map(\.name) == ["Mince"])
    }

    /// Names are capitalised on the way through, so the library does not fill with the same dish
    /// spelled three ways.
    @Test("Test The Recipe Name Is Capitalised")
    func testTheRecipeNameIsCapitalised() {
        let screen = makeScreen()
        screen.presenter.recipeName = "chilli con carne"
        screen.presenter.servingQuantity = 4

        screen.presenter.onNextPressed()

        #expect(screen.router.preparationDelegates.first?.recipeName == "Chilli Con Carne")
    }

    /// Total weight is optional, and its absence travels as zero, which the method step reads as
    /// "not given".
    @Test("Test An Absent Total Weight Travels As Zero")
    func testAnAbsentTotalWeightTravelsAsZero() {
        let screen = makeScreen()
        screen.presenter.recipeName = "Chilli"
        screen.presenter.servingQuantity = 4

        screen.presenter.onNextPressed()

        #expect(screen.router.preparationDelegates.first?.recipeTotalWeight == 0)
    }

    // MARK: - Building the ingredient list

    @Test("Test A Confirmed Ingredient Joins The List")
    func testAConfirmedIngredientJoinsTheList() {
        let screen = makeScreen()

        screen.presenter.onAddIngredientPressed()
        screen.router.builderDelegates.first?.onRecipeIngredientConfirmed?(ingredient("Mince"))

        #expect(screen.presenter.ingredients.map(\.name) == ["Mince"])
    }

    /// Confirming the same food again changes its amount rather than adding it twice — the
    /// builder is how an amount is edited as well as set.
    @Test("Test Reconfirming An Ingredient Replaces It")
    func testReconfirmingAnIngredientReplacesIt() {
        let screen = makeScreen()
        screen.presenter.onAddIngredientPressed()
        let confirm = screen.router.builderDelegates.first?.onRecipeIngredientConfirmed ?? nil

        confirm?(ingredient("Mince", amount: 100))
        confirm?(ingredient("Mince", amount: 400))

        #expect(screen.presenter.ingredients.count == 1)
        #expect(screen.presenter.ingredients.first?.amount == 400)
    }

    /// The builder is told what is already chosen so it can show those as selected.
    @Test("Test The Builder Is Told What Is Already Chosen")
    func testTheBuilderIsToldWhatIsAlreadyChosen() {
        let screen = makeScreen()
        screen.presenter.ingredients = [ingredient("Mince"), ingredient("Beans")]

        screen.presenter.onAddIngredientPressed()

        let selected = screen.router.builderDelegates.first?.selectedFoods ?? []
        #expect(selected.map(\.name) == ["Mince", "Beans"])
    }
}

/// The recipe list and a recipe's own screen.
@MainActor
struct RecipeDetailPresenterTests {

    private final class DetailInteractor: RecipeDetailInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var favouriteIds: Set<String> = []
        var setFavouriteError: Error?
        private(set) var setCalls: [(String, Bool)] = []

        func isFavouriteRecipe(id: String) -> Bool {
            favouriteIds.contains(id)
        }

        func setFavouriteRecipe(id: String, isFavourite: Bool) async throws {
            setCalls.append((id, isFavourite))
            if let setFavouriteError { throw setFavouriteError }
        }

        func deleteRecipeTemplate(id: String) async throws { }
    }

    private final class DetailRouter: RecipeDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var startDelegates: [RecipeStartDelegate] = []

        func showDevSettingsView() { }

        func showStartRecipeView(delegate: RecipeStartDelegate) {
            startDelegates.append(delegate)
        }
    }

    private final class ListInteractor: SpyGlobalInteractor, RecipesInteractor { }

    private final class ListRouter: RecipesRouter {
        private(set) var detailDelegates: [RecipeDetailDelegate] = []
        private(set) var createCount = 0

        func showRecipeDetailView(delegate: RecipeDetailDelegate) {
            detailDelegates.append(delegate)
        }

        func showSimpleAlert(title: String, subtitle: String?) { }

        func showCreateRecipeView() {
            createCount += 1
        }
    }

    private func recipe() -> RecipeTemplateModel {
        RecipeTemplateModel.newRecipeTemplate(name: "Chilli", authorId: "user-1")
    }

    @Test("Test A Recipes Favourite State Is Read On Appear")
    func testARecipesFavouriteStateIsReadOnAppear() {
        let interactor = DetailInteractor()
        let dish = recipe()
        interactor.favouriteIds = [dish.id]
        let presenter = RecipeDetailPresenter(interactor: interactor, router: DetailRouter())

        presenter.onViewAppear(delegate: RecipeDetailDelegate(recipeTemplate: dish))

        #expect(presenter.isFavourited)
    }

    /// The star flips at once rather than waiting on the write, which is what makes it feel
    /// instant.
    @Test("Test Favouriting Flips Immediately And Is Written")
    func testFavouritingFlipsImmediatelyAndIsWritten() async {
        let interactor = DetailInteractor()
        let dish = recipe()
        let presenter = RecipeDetailPresenter(interactor: interactor, router: DetailRouter())

        presenter.onFavouritePressed(delegate: RecipeDetailDelegate(recipeTemplate: dish))

        #expect(presenter.isFavourited)
        await TestManagers.eventually { !interactor.setCalls.isEmpty }
        #expect(interactor.setCalls.first?.0 == dish.id)
        #expect(interactor.setCalls.first?.1 == true)
    }

    /// And flips back if the write fails, so the star never claims a favourite that was not saved.
    @Test("Test A Failed Favourite Flips Back")
    func testAFailedFavouriteFlipsBack() async {
        let interactor = DetailInteractor()
        interactor.setFavouriteError = URLError(.networkConnectionLost)
        let presenter = RecipeDetailPresenter(interactor: interactor, router: DetailRouter())

        presenter.onFavouritePressed(delegate: RecipeDetailDelegate(recipeTemplate: recipe()))
        await TestManagers.eventually { !presenter.isFavourited }

        #expect(!presenter.isFavourited)
    }

    @Test("Test Unfavouriting Writes The Removal")
    func testUnfavouritingWritesTheRemoval() async {
        let interactor = DetailInteractor()
        let dish = recipe()
        interactor.favouriteIds = [dish.id]
        let presenter = RecipeDetailPresenter(interactor: interactor, router: DetailRouter())
        presenter.onViewAppear(delegate: RecipeDetailDelegate(recipeTemplate: dish))

        presenter.onFavouritePressed(delegate: RecipeDetailDelegate(recipeTemplate: dish))
        await TestManagers.eventually { !interactor.setCalls.isEmpty }

        #expect(!presenter.isFavourited)
        #expect(interactor.setCalls.first?.1 == false)
    }

    @Test("Test Each Ingredient Unit Has A Display Name")
    func testEachIngredientUnitHasADisplayName() {
        let presenter = RecipeDetailPresenter(interactor: DetailInteractor(), router: DetailRouter())

        #expect(presenter.displayUnit(.grams) == "g")
        #expect(presenter.displayUnit(.milliliters) == "ml")
        #expect(presenter.displayUnit(.units) == "units")
    }

    @Test("Test Starting A Recipe Opens It")
    func testStartingARecipeOpensIt() {
        let router = DetailRouter()
        let presenter = RecipeDetailPresenter(interactor: DetailInteractor(), router: router)

        presenter.onStartRecipePressed(recipe: recipe())

        #expect(router.startDelegates.first?.recipe.name == "Chilli")
    }

    @Test("Test Pressing A Recipe In The List Opens Its Detail")
    func testPressingARecipeInTheListOpensItsDetail() {
        let router = ListRouter()
        let presenter = RecipesPresenter(interactor: ListInteractor(), router: router)

        presenter.onRecipePressed(recipe: recipe())

        #expect(router.detailDelegates.first?.recipeTemplate.name == "Chilli")
    }

    @Test("Test Appearing In The List Is Tracked As A Screen View")
    func testAppearingInTheListIsTrackedAsAScreenView() {
        let interactor = ListInteractor()
        let presenter = RecipesPresenter(interactor: interactor, router: ListRouter())

        presenter.onViewAppear()

        #expect(interactor.trackedScreenEventNames == ["RecipesView_Appear"])
    }

    /// The embedded recipe picker logged "RecipesView_Appear" too, so the Recipes tab's screen-view
    /// count was the two screens added together. It is tracked under its own name now.
    @Test("Test The Embedded Recipe Picker Is Tracked Under Its Own Name")
    func testTheEmbeddedRecipePickerIsTrackedUnderItsOwnName() {
        let interactor = ListBuilderInteractor()
        let presenter = RecipeListBuilderPresenter(interactor: interactor, router: ListBuilderRouter())

        presenter.onViewAppear()
        presenter.onViewDisappear()

        #expect(interactor.trackedScreenEventNames == ["RecipeListBuilderView_Appear"])
        #expect(interactor.trackedEventNames == ["RecipeListBuilderView_Disappear"])
    }
}

/// The recipe picker embedded in the food library, which is a different screen from the Recipes tab
/// even though the two used to share an event name.
@MainActor
private final class ListBuilderInteractor: SpyGlobalInteractor, RecipeListBuilderInteractor {
    var currentUser: UserModel? = UserModel(userId: "user-1")
    var userRecipeTemplates: [RecipeTemplateModel] = []
    var foodLogSettings: FoodLogSettings = FoodLogSettings(authorId: "user-1")
}

@MainActor
private final class ListBuilderRouter: RecipeListBuilderRouter {
    let router: AnyRouter = TestRouting.anyRouter

    func showRecipeDetailView(delegate: RecipeDetailDelegate) { }
    func showCreateRecipeView() { }
    func showRecipeAmountView(delegate: RecipeAmountDelegate) { }
}

/// A food's own screen: its figures, and whether it is a favourite.
@MainActor
struct FoodDetailPresenterTests {

    private final class Interactor: SpyGlobalInteractor, FoodDetailInteractor {
        var currentUser: UserModel? = UserModel(userId: "user-1")
        var favouriteIds: Set<String> = []
        var setFavouriteError: Error?
        private(set) var setCalls: [(String, Bool)] = []

        func isFavouriteFood(id: String) -> Bool {
            favouriteIds.contains(id)
        }

        func setFavouriteFood(id: String, isFavourite: Bool) async throws {
            setCalls.append((id, isFavourite))
            if let setFavouriteError { throw setFavouriteError }
        }

        func deleteFood(ingredientId: String) async throws { }
    }

    private final class Router: FoodDetailRouter {
        let router: AnyRouter = TestRouting.anyRouter

        func showDevSettingsView() { }
    }

    private func delegate(id: String = "food-1") -> FoodDetailDelegate {
        FoodDetailDelegate(food: FoodModel(ingredientId: id, name: "Oats"))
    }

    @Test("Test A Foods Favourite State Is Read On Appear")
    func testAFoodsFavouriteStateIsReadOnAppear() {
        let interactor = Interactor()
        interactor.favouriteIds = ["food-1"]
        let presenter = FoodDetailPresenter(interactor: interactor, router: Router())

        presenter.onViewAppear(delegate: delegate())

        #expect(presenter.isFavourited)
        #expect(interactor.trackedScreenEventNames == ["FoodDetailView_Appear"])
    }

    @Test("Test Favouriting Flips Immediately And Is Written")
    func testFavouritingFlipsImmediatelyAndIsWritten() async {
        let interactor = Interactor()
        let presenter = FoodDetailPresenter(interactor: interactor, router: Router())

        presenter.onFavouritePressed(delegate: delegate())

        #expect(presenter.isFavourited)
        await TestManagers.eventually {
            interactor.trackedEventNames.contains("FoodDetailView_Favourite_Success")
        }
        #expect(interactor.setCalls.first?.0 == "food-1")
        #expect(interactor.setCalls.first?.1 == true)
    }

    /// The star flips back if the write fails, so it never claims a favourite that was not saved.
    @Test("Test A Failed Favourite Flips Back And Is Reported")
    func testAFailedFavouriteFlipsBackAndIsReported() async {
        let interactor = Interactor()
        interactor.setFavouriteError = URLError(.networkConnectionLost)
        let presenter = FoodDetailPresenter(interactor: interactor, router: Router())

        presenter.onFavouritePressed(delegate: delegate())
        await TestManagers.eventually {
            interactor.trackedEventNames.contains("FoodDetailView_Favourite_Fail")
        }

        #expect(!presenter.isFavourited)
    }
}
