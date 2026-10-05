//
//  FoodItemSearchPresenterTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
import SwiftUI
@testable import Compound

/// Searching for a food to log, across the user's own history and OpenFoodFacts.
///
/// The remote half is typed into, so it debounces: every keystroke cancels the last search rather
/// than firing one. That is the whole risk here — a search that fires per character, or one that
/// never fires, or an old answer arriving after a newer one and overwriting it.
@MainActor
struct FoodItemSearchPresenterTests {

    private final class Interactor: SpyGlobalInteractor, FoodItemSearchInteractor {
        var recentPicks: [RecentPick] = []
        var foods: [FoodModel] = []
        var userRecipeTemplates: [RecipeTemplateModel] = []
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

    /// Saved foods match on name or brand with no request at all, so they are there offline, and
    /// an online result that is already saved is listed once, under the library.
    @Test("Test Saved Foods Match Locally And Are Not Repeated Online")
    func testSavedFoodsMatchLocallyAndAreNotRepeatedOnline() async {
        let screen = makeScreen()
        let saved = FoodModel(ingredientId: "off-123", name: "Oat Milk", brandName: "Oatly")
        screen.interactor.foods = [saved, food("Banana")]
        screen.interactor.results = [saved, food("Oat Milk Barista")]

        screen.presenter.searchText = "oatly"
        #expect(screen.presenter.libraryResults.map(\.name) == ["Oat Milk"])

        screen.presenter.searchText = "oat milk"
        screen.presenter.onSearchTextChanged("oat milk")
        #expect(await TestManagers.eventually { !screen.presenter.openFoodFactsFoods.isEmpty })

        #expect(screen.presenter.libraryResults.map(\.name) == ["Oat Milk"])
        #expect(screen.presenter.onlineResults.map(\.name) == ["Oat Milk Barista"])
    }

    /// The user's recipes are searched with their foods, by name, with no request.
    @Test("Test Saved Recipes Match Locally")
    func testSavedRecipesMatchLocally() {
        let screen = makeScreen()
        screen.interactor.userRecipeTemplates = [
            RecipeTemplateModel.newRecipeTemplate(name: "Beef Chilli", authorId: "user-1"),
            RecipeTemplateModel.newRecipeTemplate(name: "Pancakes", authorId: "user-1")
        ]

        screen.presenter.searchText = "chilli"

        #expect(screen.presenter.recipeResults.map(\.name) == ["Beef Chilli"])
    }

    /// What the user logged before is offered before they type anything — most logging is
    /// repetition, so the history is the common case rather than the fallback.
    @Test("Test Recent Foods Are Offered On Appear")
    func testRecentFoodsAreOfferedOnAppear() {
        let screen = makeScreen()
        screen.interactor.recentPicks = [.food(food("Oats")), .food(food("Milk"))]

        screen.presenter.onViewAppear(delegate: screen.delegate)

        #expect(screen.presenter.history.map(\.id) == ["food-Oats", "food-Milk"])
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
        // Offline says so, rather than the generic "couldn't search".
        #expect(screen.presenter.searchFailedOffline)
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
