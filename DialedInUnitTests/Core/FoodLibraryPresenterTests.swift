//
//  FoodLibraryPresenterTests.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 21/09/2026.
//

import Testing
import Foundation
import SwiftUI
@testable import DialedIn

/// Searching for a food to log, across the user's own history and OpenFoodFacts.
///
/// The remote half is typed into, so it debounces: every keystroke cancels the last search rather
/// than firing one. That is the whole risk here — a search that fires per character, or one that
/// never fires, or an old answer arriving after a newer one and overwriting it.
@MainActor
struct FoodItemSearchPresenterTests {

    private final class Interactor: SpyGlobalInteractor, FoodItemSearchInteractor {
        var recentFoods: [FoodModel] = []
        var foodLogSettings: FoodLogSettings = FoodLogSettings(authorId: "user-1")
        var results: [FoodModel] = []
        var resultsByQuery: [String: [FoodModel]] = [:]
        var error: Error?
        private(set) var queries: [String] = []

        private var held: Set<String> = []
        private var gates: [String: CheckedContinuation<Void, Never>] = [:]

        /// Leaves the next search for `query` suspended, standing in for a request still in
        /// flight at the remote, until `release(_:)` answers it.
        func hold(_ query: String) {
            held.insert(query)
        }

        func release(_ query: String) {
            gates.removeValue(forKey: query)?.resume()
        }

        func searchOpenFoodFacts(query: String) async throws -> [FoodModel] {
            queries.append(query)
            if held.remove(query) != nil {
                await withCheckedContinuation { gates[query] = $0 }
            }
            if let error { throw error }
            return resultsByQuery[query] ?? results
        }
    }

    private final class Router: FoodItemSearchRouter {
        let router: AnyRouter = TestRouting.anyRouter
    }

    private struct Screen {
        let presenter: FoodItemSearchPresenter
        let interactor: Interactor
        let delegate = FoodItemSearchDelegate()
    }

    /// The debounce is driven short here so the tests wait on the search landing rather than on
    /// the clock. At the shipped 700ms every one of these was a race against the machine's load.
    private static let debounce: Duration = .milliseconds(10)

    private func makeScreen() -> Screen {
        let interactor = Interactor()
        return Screen(
            presenter: FoodItemSearchPresenter(
                interactor: interactor,
                router: Router(),
                searchDebounce: Self.debounce
            ),
            interactor: interactor
        )
    }

    /// Waits out the debounce and then some, for the tests that have to show a search *never*
    /// fires. There is no state to poll for something that does not happen.
    private func waitPastTheDebounce() async {
        try? await Task.sleep(for: Self.debounce * 20)
    }

    private func food(_ name: String, brand: String? = nil) -> FoodModel {
        FoodModel(ingredientId: name, name: name, brandName: brand)
    }

    /// What the user logged before is offered before they type anything — most logging is
    /// repetition, so the history is the common case rather than the fallback.
    @Test("Test Recent Foods Are Offered On Appear")
    func testRecentFoodsAreOfferedOnAppear() {
        let screen = makeScreen()
        screen.interactor.recentFoods = [food("Oats"), food("Milk")]

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.presenter.historyFoods.map(\.name) == ["Oats", "Milk"])
    }

    /// Offline the remote search is not tried, and no alert rises per keystroke: the failed state
    /// says why the online results are missing.
    @Test("Test Offline The Remote Search Is Skipped And Marked Failed")
    func testOfflineTheRemoteSearchIsSkippedAndMarkedFailed() async {
        let screen = makeScreen()
        screen.interactor.isOffline = true

        screen.presenter.onSearchTextChanged("oat")
        await waitPastTheDebounce()

        #expect(screen.interactor.queries.isEmpty)
        #expect(screen.presenter.searchFailed)
        #expect(!screen.presenter.isSearching)
    }

    @Test("Test A Query Reaches The Remote Search")
    func testAQueryReachesTheRemoteSearch() async {
        let screen = makeScreen()
        screen.interactor.results = [food("Oat Milk")]

        screen.presenter.onSearchTextChanged("oat")
        await TestManagers.eventually { !screen.presenter.openFoodFactsFoods.isEmpty }

        #expect(screen.interactor.queries == ["oat"])
        #expect(screen.presenter.openFoodFactsFoods.map(\.name) == ["Oat Milk"])
    }

    /// The query is trimmed before it is sent, so a trailing space from the keyboard does not
    /// become a different search than the same word without it.
    @Test("Test The Query Is Trimmed Before It Is Sent")
    func testTheQueryIsTrimmedBeforeItIsSent() async {
        let screen = makeScreen()
        screen.interactor.results = [food("Oat Milk")]

        screen.presenter.onSearchTextChanged("  oat  ")
        await TestManagers.eventually { !screen.interactor.queries.isEmpty }

        #expect(screen.interactor.queries == ["oat"])
    }

    /// Typing is a stream of changes, and only the last one should reach the network — otherwise
    /// "oat milk" is eight searches.
    @Test("Test Typing Only Searches For What Was Last Typed")
    func testTypingOnlySearchesForWhatWasLastTyped() async {
        let screen = makeScreen()
        screen.interactor.results = [food("Oat Milk")]

        screen.presenter.onSearchTextChanged("o")
        screen.presenter.onSearchTextChanged("oa")
        screen.presenter.onSearchTextChanged("oat")
        await TestManagers.eventually { !screen.presenter.openFoodFactsFoods.isEmpty }

        #expect(screen.interactor.queries == ["oat"])
    }

    /// Cancelling a search cannot recall a request already in flight at the remote, so the
    /// superseded answer still arrives. It has to be dropped on arrival — otherwise the results
    /// for "oat" land on top of the ones the user is looking at for "oats".
    @Test("Test A Superseded Search Does Not Overwrite The Newer One")
    func testASupersededSearchDoesNotOverwriteTheNewerOne() async {
        let screen = makeScreen()
        screen.interactor.resultsByQuery = ["oat": [food("Oat Milk")], "oats": [food("Oats")]]
        screen.interactor.hold("oat")

        screen.presenter.onSearchTextChanged("oat")
        await TestManagers.eventually { screen.interactor.queries == ["oat"] }

        screen.presenter.onSearchTextChanged("oats")
        await TestManagers.eventually { screen.presenter.openFoodFactsFoods.map(\.name) == ["Oats"] }

        screen.interactor.release("oat")
        await waitPastTheDebounce()

        #expect(screen.presenter.openFoodFactsFoods.map(\.name) == ["Oats"])
        #expect(!screen.presenter.isSearching)
    }

    /// Clearing the field drops the results immediately rather than waiting on a search, and asks
    /// for nothing — an empty query has no answer.
    @Test("Test Clearing The Field Clears The Results And Searches For Nothing")
    func testClearingTheFieldClearsTheResultsAndSearchesForNothing() async {
        let screen = makeScreen()
        screen.interactor.results = [food("Oat Milk")]
        screen.presenter.onSearchTextChanged("oat")
        await TestManagers.eventually { !screen.presenter.openFoodFactsFoods.isEmpty }

        screen.presenter.onSearchTextChanged("")

        #expect(screen.presenter.openFoodFactsFoods.isEmpty)
        // Past the debounce, or an empty query that *was* searched for would still be waiting.
        await waitPastTheDebounce()
        #expect(screen.interactor.queries == ["oat"])
    }

    @Test("Test A Whitespace Only Query Is Not Searched")
    func testAWhitespaceOnlyQueryIsNotSearched() async {
        let screen = makeScreen()

        screen.presenter.onSearchTextChanged("   ")
        await waitPastTheDebounce()

        #expect(screen.interactor.queries.isEmpty)
    }

    /// The setting is the user saying they do not want results from the public database, so no
    /// request is made at all rather than results being fetched and hidden.
    @Test("Test Remote Results Are Not Fetched When Turned Off")
    func testRemoteResultsAreNotFetchedWhenTurnedOff() async {
        let screen = makeScreen()
        screen.interactor.foodLogSettings.showOpenFoodFactsFoods = false

        screen.presenter.onSearchTextChanged("oat")
        await waitPastTheDebounce()

        #expect(screen.interactor.queries.isEmpty)
        #expect(screen.presenter.openFoodFactsFoods.isEmpty)
    }

    /// Branded foods are filtered out of the answer rather than out of the request, since the
    /// remote search has no way to ask for unbranded results only.
    @Test("Test Branded Results Are Dropped When Turned Off")
    func testBrandedResultsAreDroppedWhenTurnedOff() async {
        let screen = makeScreen()
        screen.interactor.foodLogSettings.showBrandedFoods = false
        screen.interactor.results = [food("Oat Milk", brand: "Brand"), food("Oats")]

        screen.presenter.onSearchTextChanged("oat")
        await TestManagers.eventually { !screen.presenter.openFoodFactsFoods.isEmpty }

        #expect(screen.presenter.openFoodFactsFoods.map(\.name) == ["Oats"])
    }

    /// A failed search empties the results and says so in the log. Leaving the last query's
    /// results up would show them as though they answered this one.
    @Test("Test A Failed Search Clears The Results And Is Reported")
    func testAFailedSearchClearsTheResultsAndIsReported() async {
        let screen = makeScreen()
        screen.interactor.results = [food("Oat Milk")]
        screen.presenter.onSearchTextChanged("oat")
        await TestManagers.eventually { !screen.presenter.openFoodFactsFoods.isEmpty }

        screen.interactor.error = URLError(.notConnectedToInternet)
        screen.presenter.onSearchTextChanged("oats")
        await TestManagers.eventually {
            screen.interactor.trackedEventNames.contains("FoodItemSearchView_SearchError")
        }

        #expect(screen.presenter.openFoodFactsFoods.isEmpty)
        #expect(!screen.presenter.isSearching)
        // Empty results and a failed request read identically without this: the screen would say
        // "No results found", asserting the food does not exist when it was never looked for.
        #expect(screen.presenter.searchFailed)
    }

    /// And the failure does not stick: the next search starts from a clean state, so a query that
    /// genuinely has no results is still reported as having none.
    @Test("Test A Later Search Clears The Failure")
    func testALaterSearchClearsTheFailure() async {
        let screen = makeScreen()
        screen.interactor.error = URLError(.notConnectedToInternet)
        screen.presenter.onSearchTextChanged("oat")
        await TestManagers.eventually { screen.presenter.searchFailed }

        screen.interactor.error = nil
        screen.interactor.results = [food("Oat Milk")]
        screen.presenter.onSearchTextChanged("oats")
        await TestManagers.eventually { !screen.presenter.openFoodFactsFoods.isEmpty }

        #expect(!screen.presenter.searchFailed)
    }

    /// Leaving cancels whatever is in flight, so a result cannot arrive against a screen that has
    /// gone.
    @Test("Test Leaving Cancels A Search In Flight")
    func testLeavingCancelsASearchInFlight() async {
        let screen = makeScreen()
        screen.interactor.results = [food("Oat Milk")]

        screen.presenter.onSearchTextChanged("oat")
        screen.presenter.onViewDisappear(delegate: screen.delegate)
        await waitPastTheDebounce()

        #expect(screen.interactor.queries.isEmpty)
        #expect(screen.presenter.openFoodFactsFoods.isEmpty)
    }

    @Test("Test Appearing Is Tracked As A Screen View")
    func testAppearingIsTrackedAsAScreenView() {
        let screen = makeScreen()

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.interactor.trackedScreenEventNames == ["FoodItemSearchView_Appear"])
    }
}

/// The library tab: recipes, foods, and the favourites of both.
@MainActor
struct FoodLibraryPresenterTests {

    private final class Interactor: SpyGlobalInteractor, FoodLibraryInteractor {
        var foods: [FoodModel] = []
        var userRecipeTemplates: [RecipeTemplateModel] = []
        var foodLogSettings: FoodLogSettings = FoodLogSettings(authorId: "user-1")
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

    @Test("Test A Favourite Recipe Opens Its Detail")
    func testAFavouriteRecipeOpensItsDetail() {
        let screen = makeScreen()

        screen.presenter.onFavouriteRecipePressed(recipe("Chilli"))

        #expect(screen.router.recipeDetailDelegates.first?.recipeTemplate.name == "Chilli")
    }

    @Test("Test The Search Prompt Follows The Tab")
    func testTheSearchPromptFollowsTheTab() {
        let screen = makeScreen()

        screen.presenter.foodLibraryOption = .recipes
        #expect(screen.presenter.searchPrompt == "Filter Recipes")

        screen.presenter.foodLibraryOption = .favourites
        #expect(screen.presenter.searchPrompt == "Filter Favourites")
    }
}

/// The picker that fronts every way of adding food, and the foods list behind it.
@MainActor
struct NutritionPickerPresenterTests {

    private final class PickerInteractor: SpyGlobalInteractor, NutritionLibraryPickerInteractor {
        var foodLogSettings: FoodLogSettings = FoodLogSettings(authorId: "user-1")
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

        screen.presenter.navToIngredientAmount(external, onPick: { _ in })
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

        screen.presenter.navToIngredientAmount(owned, onPick: { _ in })

        #expect(screen.interactor.savedExternalFoods.isEmpty)
        #expect(screen.router.amountDelegates.count == 1)
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
            onPick: { picked.append($0) }
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
        screen.presenter.navToIngredientAmount(oats, onPick: { picked.append($0) })

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
        screen.presenter.navToIngredientAmount(rice, onPick: { picked.append($0) })

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
        screen.presenter.navToIngredientAmount(milk, onPick: { picked.append($0) })

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

        screen.presenter.navToIngredientAmount(external, onPick: { _ in })
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
