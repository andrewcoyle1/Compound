//
//  FoodLibraryPresenterTests.swift
//  CompoundUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// The library tab: recipes, foods, and the favourites of both.
@MainActor
struct FoodLibraryPresenterTests {

    private final class Interactor: SpyGlobalInteractor, FoodLibraryInteractor {
        var foods: [FoodModel] = []
        var userRecipeTemplates: [RecipeTemplateModel] = []
        var foodLogSettings: FoodLogSettings = FoodLogSettings(authorId: "user-1")
        var userMeals: [MealLogModel] = []
    }

    private final class Router: FoodLibraryRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var amountDelegates: [IngredientAmountDelegate] = []
        private(set) var recipeDetailDelegates: [RecipeDetailDelegate] = []

        func showIngredientAmountView(delegate: IngredientAmountDelegate) {
            amountDelegates.append(delegate)
        }

        func showRecipeDetailView(delegate: RecipeDetailDelegate) {
            recipeDetailDelegates.append(delegate)
        }

        private(set) var recipeAmountDelegates: [RecipeAmountDelegate] = []
        func showRecipeAmountView(delegate: RecipeAmountDelegate) {
            recipeAmountDelegates.append(delegate)
        }
    }

    private struct Screen {
        let presenter: FoodLibraryPresenter
        let interactor: Interactor
        let router: Router
    }

    private func makeScreen(quickAdd: Bool = false) -> Screen {
        let interactor = Interactor()
        interactor.foodLogSettings.quickAddEnabled = quickAdd
        let router = Router()
        return Screen(
            presenter: FoodLibraryPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    private func food(_ name: String) -> FoodModel {
        FoodModel(ingredientId: name, name: name)
    }

    private func recipe(_ name: String) -> RecipeTemplateModel {
        RecipeTemplateModel.newRecipeTemplate(name: name, authorId: "user-1")
    }

    // MARK: - Tabs

    @Test("Test Changing Tab Clears The Search And Plays A Selection Haptic")
    func testChangingTabClearsTheSearchAndPlaysASelectionHaptic() {
        let screen = makeScreen()
        screen.presenter.searchText = "oat"

        screen.presenter.foodLibraryOption = .foods
        screen.presenter.onLibraryOptionChanged()

        #expect(screen.presenter.searchText.isEmpty)
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["selection"])
    }

    // MARK: - Favourites

    @Test("Test Favourite Foods Are Resolved From Their Ids")
    func testFavouriteFoodsAreResolvedFromTheirIds() {
        let screen = makeScreen()
        screen.interactor.foods = [food("Oats"), food("Milk"), food("Honey")]
        screen.interactor.foodLogSettings.favouriteFoodIds = ["Oats", "Honey"]

        #expect(screen.presenter.favouriteFoods.map(\.name) == ["Honey", "Oats"])
    }

    /// A favourite whose food has since been deleted is dropped rather than drawn as a blank row
    /// the user cannot open or remove.
    @Test("Test A Favourite Whose Food Is Gone Is Dropped")
    func testAFavouriteWhoseFoodIsGoneIsDropped() {
        let screen = makeScreen()
        screen.interactor.foods = [food("Oats")]
        screen.interactor.foodLogSettings.favouriteFoodIds = ["Oats", "Deleted"]

        #expect(screen.presenter.favouriteFoods.map(\.name) == ["Oats"])
    }

    @Test("Test Favourites Are Sorted By Name")
    func testFavouritesAreSortedByName() {
        let screen = makeScreen()
        screen.interactor.foods = [food("Yoghurt"), food("Apples"), food("Milk")]
        screen.interactor.foodLogSettings.favouriteFoodIds = ["Yoghurt", "Apples", "Milk"]

        #expect(screen.presenter.favouriteFoods.map(\.name) == ["Apples", "Milk", "Yoghurt"])
    }

    /// The filter is a contains match and ignores case, which is what a user typing three letters
    /// into a filter box expects.
    @Test("Test The Filter Matches Part Of A Name Regardless Of Case")
    func testTheFilterMatchesPartOfANameRegardlessOfCase() {
        let screen = makeScreen()
        screen.interactor.foods = [food("Oat Milk"), food("Whole Milk"), food("Apples")]
        screen.interactor.foodLogSettings.favouriteFoodIds = ["Oat Milk", "Whole Milk", "Apples"]

        screen.presenter.searchText = "MILK"

        #expect(screen.presenter.favouriteFoods.map(\.name) == ["Oat Milk", "Whole Milk"])
    }

    @Test("Test An Empty Filter Shows Everything")
    func testAnEmptyFilterShowsEverything() {
        let screen = makeScreen()
        screen.interactor.foods = [food("Oats"), food("Milk")]
        screen.interactor.foodLogSettings.favouriteFoodIds = ["Oats", "Milk"]

        screen.presenter.searchText = "   "

        #expect(screen.presenter.favouriteFoods.count == 2)
    }

    @Test("Test Favourite Recipes Are Resolved And Filtered The Same Way")
    func testFavouriteRecipesAreResolvedAndFilteredTheSameWay() {
        let screen = makeScreen()
        let chilli = recipe("Chilli")
        let curry = recipe("Curry")
        screen.interactor.userRecipeTemplates = [chilli, curry]
        screen.interactor.foodLogSettings.favouriteRecipeIds = [chilli.id, curry.id]

        screen.presenter.searchText = "chil"

        #expect(screen.presenter.favouriteRecipes.map(\.name) == ["Chilli"])
    }

    @Test("Test Having No Favourites Is Reported")
    func testHavingNoFavouritesIsReported() {
        let screen = makeScreen()

        #expect(!screen.presenter.hasFavourites)

        screen.interactor.foodLogSettings.favouriteFoodIds = ["Oats"]
        #expect(screen.presenter.hasFavourites)
    }

    // MARK: - Opening a favourite

    /// The default. A favourite goes through the amount step like anything else, because adding
    /// it at some assumed quantity would log a number the user never chose.
    @Test("Test A Favourite Food Opens The Amount Step")
    func testAFavouriteFoodOpensTheAmountStep() {
        let screen = makeScreen()
        #expect(screen.interactor.foodLogSettings.quickAddEnabled == false)

        var picked: [MealItemModel] = []
        screen.presenter.onFavouriteFoodPressed(food("Oats"), onPick: { picked.append($0) })

        #expect(screen.router.amountDelegates.count == 1)
        #expect(screen.router.amountDelegates.first?.ingredient.name == "Oats")
        #expect(picked.isEmpty)
    }

    /// Quick Add is the user asking for that assumed quantity: the food's own portion, logged
    /// without the amount step.
    @Test("Test Quick Add Logs A Favourite Without The Amount Step")
    func testQuickAddLogsAFavouriteWithoutTheAmountStep() throws {
        let screen = makeScreen(quickAdd: true)
        let oats = FoodModel(ingredientId: "oats", name: "Oats", servingWeight: 40)

        var picked: [MealItemModel] = []
        screen.presenter.onFavouriteFoodPressed(oats, onPick: { picked.append($0) })

        #expect(screen.router.amountDelegates.isEmpty)
        let item = try #require(picked.first)
        #expect(item.displayName == "Oats")
        #expect(item.amount == 40)
    }

    /// Browsing, a favourite recipe opens its page.
    @Test("Test A Favourite Recipe Opens Its Detail")
    func testAFavouriteRecipeOpensItsDetail() {
        let screen = makeScreen()

        screen.presenter.onFavouriteRecipePressed(recipe("Chilli"))

        #expect(screen.router.recipeDetailDelegates.first?.recipeTemplate.name == "Chilli")
    }

    /// Logging, a favourite recipe goes to its servings with the plate's Log, like every other
    /// recipe row. It used to open the recipe's page, which cannot log it.
    @Test("Test A Favourite Recipe Picked While Logging Opens Its Servings")
    func testAFavouriteRecipePickedWhileLoggingOpensItsServings() {
        let screen = makeScreen()
        var logged = 0

        screen.presenter.onFavouriteRecipePressed(recipe("Chilli"), onPick: { _ in }, onLog: { logged += 1 })
        screen.router.recipeAmountDelegates.first?.onLog?()

        #expect(screen.router.recipeDetailDelegates.isEmpty)
        #expect(screen.router.recipeAmountDelegates.first?.recipe.name == "Chilli")
        #expect(logged == 1)
    }

    @Test("Test The Search Prompt Follows The Tab")
    func testTheSearchPromptFollowsTheTab() {
        let screen = makeScreen()

        screen.presenter.foodLibraryOption = .recipes
        #expect(screen.presenter.searchPrompt == "Filter Recipes")

        screen.presenter.foodLibraryOption = .favourites
        #expect(screen.presenter.searchPrompt == "Filter Favorites")
    }
}

/// The picker that fronts every way of adding food, and the foods list behind it.
@MainActor
struct NutritionPickerPresenterTests {

    private final class PickerInteractor: SpyGlobalInteractor, NutritionLibraryPickerInteractor {
        var foodLogSettings: FoodLogSettings = FoodLogSettings(authorId: "user-1")
        var userMeals: [MealLogModel] = []
        private(set) var savedExternalFoods: [FoodModel] = []

        func saveExternalFood(_ food: FoodModel) async {
            savedExternalFoods.append(food)
        }
    }

    /// `showDevSettingsView()` unguarded — the test target builds without `-DDEV`.
    private final class PickerRouter: NutritionLibraryPickerRouter {
        let router: AnyRouter = TestRouting.anyRouter
        private(set) var amountDelegates: [IngredientAmountDelegate] = []
        private(set) var recipeAmountDelegates: [RecipeAmountDelegate] = []

        func showIngredientAmountView(delegate: IngredientAmountDelegate) {
            amountDelegates.append(delegate)
        }

        func showRecipeAmountView(delegate: RecipeAmountDelegate) {
            recipeAmountDelegates.append(delegate)
        }

        func showDevSettingsView() { }
    }

    private struct Screen {
        let presenter: NutritionLibraryPickerPresenter
        let interactor: PickerInteractor
        let router: PickerRouter
    }

    private func makeScreen(quickAdd: Bool = false) -> Screen {
        let interactor = PickerInteractor()
        interactor.foodLogSettings.quickAddEnabled = quickAdd
        let router = PickerRouter()
        return Screen(
            presenter: NutritionLibraryPickerPresenter(interactor: interactor, router: router),
            interactor: interactor,
            router: router
        )
    }

    /// The picker opens on search, which is the way most food gets logged.
    @Test("Test The Picker Opens On Search")
    func testThePickerOpensOnSearch() {
        let screen = makeScreen()

        #expect(screen.presenter.mode == .search)
    }

    @Test("Test Choosing A Mode Switches To It")
    func testChoosingAModeSwitchesToIt() {
        let screen = makeScreen()

        screen.presenter.onModePressed(.barcode)
        #expect(screen.presenter.mode == .barcode)

        screen.presenter.onModePressed(.quickAdd)
        #expect(screen.presenter.mode == .quickAdd)
    }

    /// Switching mode is a segment change, so it clicks; tapping the mode already shown does not.
    @Test("Test Switching Mode Plays A Selection Haptic Once")
    func testSwitchingModePlaysASelectionHapticOnce() {
        let screen = makeScreen()

        screen.presenter.onModePressed(.barcode)
        screen.presenter.onModePressed(.barcode)

        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["selection"])
    }

    @Test("Test Every Mode Has A Title And An Icon")
    func testEveryModeHasATitleAndAnIcon() {
        for mode in NutritionPickerMode.allCases {
            #expect(!mode.title.isEmpty)
            #expect(!mode.systemName.isEmpty)
        }
    }

    /// A food from the public database has no author, so it is copied into the user's own library
    /// on the way past. Without that, the logged item would point at a food they do not own and
    /// could not edit.
    @Test("Test An External Food Is Taken Into The Library")
    func testAnExternalFoodIsTakenIntoTheLibrary() async {
        let screen = makeScreen()
        let external = FoodModel(ingredientId: "off-1", authorId: nil, name: "Oat Milk")

        screen.presenter.navToIngredientAmount(external, onPick: { _ in }, onLog: {})
        await TestManagers.eventually { !screen.interactor.savedExternalFoods.isEmpty }

        #expect(screen.interactor.savedExternalFoods.map(\.name) == ["Oat Milk"])
        #expect(screen.router.amountDelegates.count == 1)
    }

    /// A food the user already owns is not re-saved, which would overwrite their own edits with
    /// the version being browsed.
    @Test("Test An Owned Food Is Not Re-Saved")
    func testAnOwnedFoodIsNotReSaved() async {
        let screen = makeScreen()
        let owned = FoodModel(ingredientId: "food-1", authorId: "user-1", name: "My Oat Milk")

        screen.presenter.navToIngredientAmount(owned, onPick: { _ in }, onLog: {})

        #expect(screen.interactor.savedExternalFoods.isEmpty)
        #expect(screen.router.amountDelegates.count == 1)
    }

    /// The amount screen opened from the picker can log the plate, so it is handed the plate's Log.
    @Test("Test The Amount Screen Is Handed The Plates Log")
    func testTheAmountScreenIsHandedThePlatesLog() {
        let screen = makeScreen()
        var logged = 0

        screen.presenter.navToIngredientAmount(FoodModel(ingredientId: "oats", authorId: "user-1", name: "Oats"), onPick: { _ in }, onLog: { logged += 1 })
        screen.router.amountDelegates.first?.onLog?()

        #expect(logged == 1)
    }

    /// A row's "+" adds at once whatever the Quick Add setting, at the amount last logged.
    @Test("Test A Rows Plus Adds The Last Amount Without The Amount Screen")
    func testARowsPlusAddsTheLastAmountWithoutTheAmountScreen() throws {
        let screen = makeScreen()
        let oats = FoodModel(ingredientId: "oats", authorId: "user-1", name: "Oats", nutrients: [.calories: 380], servingWeight: 40)
        screen.interactor.userMeals = [MealLogModel(authorId: "user-1", dayKey: Date().dayKey, date: Date(), items: [oats.mealItem(amount: 65)])]

        var picked: [MealItemModel] = []
        screen.presenter.quickAdd(oats, onPick: { picked.append($0) })

        #expect(screen.router.amountDelegates.isEmpty)
        #expect(try #require(picked.first).amount == 65)
        #expect(screen.interactor.playedHaptics.map { "\($0)" } == ["success"])
    }

    // MARK: - Quick Add

    /// The default. Every food goes through the amount step, which is what every user has today.
    @Test("Test Quick Add Is Off And The Amount Step Is Shown")
    func testQuickAddIsOffAndTheAmountStepIsShown() {
        let screen = makeScreen()
        #expect(screen.interactor.foodLogSettings.quickAddEnabled == false)

        var picked: [MealItemModel] = []
        screen.presenter.navToIngredientAmount(
            FoodModel(ingredientId: "oats", authorId: "user-1", name: "Oats", servingWeight: 40),
            onPick: { picked.append($0) },
            onLog: {}
        )

        #expect(screen.router.amountDelegates.count == 1)
        #expect(picked.isEmpty)
    }

    /// On, the food is logged at the portion it declares and the amount screen never opens.
    @Test("Test Quick Add Logs The Declared Portion")
    func testQuickAddLogsTheDeclaredPortion() throws {
        let screen = makeScreen(quickAdd: true)
        let oats = FoodModel(
            ingredientId: "oats",
            authorId: "user-1",
            name: "Oats",
            nutrients: [.calories: 380],
            servingWeight: 40
        )

        var picked: [MealItemModel] = []
        screen.presenter.navToIngredientAmount(oats, onPick: { picked.append($0) }, onLog: {})

        #expect(screen.router.amountDelegates.isEmpty)
        let item = try #require(picked.first)
        #expect(item.amount == 40)
        #expect(item.unit == "g")
        #expect(item.resolvedGrams == 40)
        #expect(item.resolvedMilliliters == nil)
        // Nutrients are per 100 g, so 40 g of a 380 kcal food is 152 kcal.
        #expect(item.calories == 152)
    }

    /// A food that declares no portion falls back to 100 — the basis its nutrients are recorded
    /// against, so the figures logged are exactly the ones stored.
    @Test("Test Quick Add Falls Back To The Hundred Gram Basis")
    func testQuickAddFallsBackToTheHundredGramBasis() throws {
        let screen = makeScreen(quickAdd: true)
        let rice = FoodModel(ingredientId: "rice", authorId: "user-1", name: "Rice", nutrients: [.calories: 130])

        var picked: [MealItemModel] = []
        screen.presenter.navToIngredientAmount(rice, onPick: { picked.append($0) }, onLog: {})

        let item = try #require(picked.first)
        #expect(item.amount == 100)
        #expect(item.calories == 130)
    }

    /// A drink is counted in millilitres, and its portion comes from the volume field rather than
    /// the mass one.
    @Test("Test Quick Add Logs A Volume Food In Millilitres")
    func testQuickAddLogsAVolumeFoodInMillilitres() throws {
        let screen = makeScreen(quickAdd: true)
        let milk = FoodModel(
            ingredientId: "milk",
            authorId: "user-1",
            name: "Milk",
            measurementMethod: .volume,
            nutrients: [.calories: 50],
            portionVolume: 250
        )

        var picked: [MealItemModel] = []
        screen.presenter.navToIngredientAmount(milk, onPick: { picked.append($0) }, onLog: {})

        let item = try #require(picked.first)
        #expect(item.amount == 250)
        #expect(item.unit == "ml")
        #expect(item.resolvedMilliliters == 250)
        #expect(item.resolvedGrams == nil)
    }

    /// The copy into the user's library still happens: a quick-added external food would
    /// otherwise point at a food they do not own.
    @Test("Test Quick Add Still Takes An External Food Into The Library")
    func testQuickAddStillTakesAnExternalFoodIntoTheLibrary() async {
        let screen = makeScreen(quickAdd: true)
        let external = FoodModel(ingredientId: "off-1", authorId: nil, name: "Oat Milk")

        screen.presenter.navToIngredientAmount(external, onPick: { _ in }, onLog: {})
        await TestManagers.eventually { !screen.interactor.savedExternalFoods.isEmpty }

        #expect(screen.interactor.savedExternalFoods.map(\.name) == ["Oat Milk"])
        #expect(screen.router.amountDelegates.isEmpty)
    }

    @Test("Test Choosing A Recipe Opens Its Amount Step")
    func testChoosingARecipeOpensItsAmountStep() {
        let screen = makeScreen()
        let chilli = RecipeTemplateModel.newRecipeTemplate(name: "Chilli", authorId: "user-1")

        screen.presenter.navToRecipeAmount(chilli, onPick: { _ in })

        #expect(screen.router.recipeAmountDelegates.first?.recipe.name == "Chilli")
    }
}

/// The foods list.
@MainActor
struct FoodsPresenterTests {

    private final class Interactor: SpyGlobalInteractor, FoodsInteractor { }

    /// `FoodsRouter` does not extend `GlobalRouter`, so this double needs only its two methods.
    private final class Router: FoodsRouter {
        private(set) var foodDetailDelegates: [FoodDetailDelegate] = []

        func showFoodDetailView(delegate: FoodDetailDelegate) {
            foodDetailDelegates.append(delegate)
        }

        func showSimpleAlert(title: String, subtitle: String?) { }
    }

    @Test("Test Pressing A Food Opens Its Detail")
    func testPressingAFoodOpensItsDetail() {
        let router = Router()
        let presenter = FoodsPresenter(interactor: Interactor(), router: router)

        presenter.onIngredientPressed(ingredient: FoodModel(ingredientId: "f1", name: "Oats"))

        #expect(router.foodDetailDelegates.first?.food.name == "Oats")
    }
}
