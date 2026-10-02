import SwiftUI

@Observable
@MainActor
class FoodItemSearchPresenter {

    private let interactor: FoodItemSearchInteractor
    private let router: FoodItemSearchRouter

    private(set) var historyFoods: [FoodModel] = []
    private(set) var openFoodFactsFoods: [FoodModel] = []
    private(set) var isSearching: Bool = false

    /// Set when the last search could not be run at all. Empty results and a failed request are
    /// not the same thing, and "No results found" claims the food does not exist.
    private(set) var searchFailed: Bool = false
    /// Why the online results are missing, when the reason is that there is no connection.
    private(set) var searchFailedOffline: Bool = false

    var searchText: String = ""

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    /// The user's own foods matching the query, by name or brand. They come first and need no
    /// connection, which is what the offline message promises; the screen used to search only
    /// Open Food Facts, so offline it showed nothing at all.
    var libraryResults: [FoodModel] {
        let query = trimmedQuery
        guard !query.isEmpty else { return [] }
        return Array(interactor.foods.filter {
            $0.name.localizedStandardContains(query) || ($0.brandName?.localizedStandardContains(query) ?? false)
        }.prefix(20))
    }

    /// The Logger Food Tiles settings, which the library's rows already honoured and these ignored.
    var tileSettings: FoodLogSettings {
        interactor.foodLogSettings
    }

    /// Whether the Open Food Facts section appears at all; the Food Log settings can turn it off.
    var searchesOnline: Bool {
        interactor.foodLogSettings.showOpenFoodFactsFoods
    }

    /// Open Food Facts results less the ones already in the library, which are listed above them.
    var onlineResults: [FoodModel] {
        let saved = Set(libraryResults.map(\.ingredientId))
        return openFoodFactsFoods.filter { !saved.contains($0.ingredientId) }
    }

    private var searchTask: Task<Void, Never>?

    /// How long typing has to stop before the query is sent. Long enough that a word typed at
    /// speed is one request, and injectable so a test can drive the debounce rather than wait it
    /// out — a real wait makes every search test a race against the machine's load.
    private let searchDebounce: Duration

    init(
        interactor: FoodItemSearchInteractor,
        router: FoodItemSearchRouter,
        searchDebounce: Duration = .milliseconds(700)
    ) {
        self.interactor = interactor
        self.router = router
        self.searchDebounce = searchDebounce
    }

    func onViewAppear(delegate: FoodItemSearchDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        historyFoods = interactor.recentFoods
    }

    func onViewDisappear(delegate: FoodItemSearchDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
        searchTask?.cancel()
        isSearching = false
    }

    func onSearchTextChanged(_ text: String) {
        searchTask?.cancel()
        // The cancelled task returns whenever its request does, so it can no longer be trusted to
        // put the spinner away.
        isSearching = false
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        searchFailed = false
        searchFailedOffline = false
        guard !trimmed.isEmpty else {
            openFoodFactsFoods = []
            return
        }
        guard interactor.foodLogSettings.showOpenFoodFactsFoods else {
            openFoodFactsFoods = []
            return
        }
        // No alert: this runs per keystroke. The library's own results still show, and the failed
        // state says why the online ones are missing.
        guard !interactor.isOffline else {
            openFoodFactsFoods = []
            searchFailed = true
            searchFailedOffline = true
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: searchDebounce)
            guard !Task.isCancelled else { return }
            isSearching = true
            do {
                let found = try await interactor.searchOpenFoodFacts(query: trimmed)
                // Cancelling cannot recall a request already in flight, so a superseded search
                // still answers. Dropping it here is what keeps it off the newer query's results.
                guard !Task.isCancelled else { return }
                openFoodFactsFoods = interactor.foodLogSettings.showBrandedFoods
                    ? found
                    : found.filter { $0.brandName == nil }
            } catch {
                guard !Task.isCancelled else { return }
                interactor.trackEvent(event: Event.searchError(error: error))
                openFoodFactsFoods = []
                searchFailed = true
            }
            isSearching = false
        }
    }
}

extension FoodItemSearchPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: FoodItemSearchDelegate)
        case onDisappear(delegate: FoodItemSearchDelegate)
        case searchError(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:    return "FoodItemSearchView_Appear"
            case .onDisappear: return "FoodItemSearchView_Disappear"
            case .searchError: return "FoodItemSearchView_SearchError"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(let delegate), .onDisappear(let delegate):
                return delegate.eventParameters
            case .searchError(error: let error):
                return error.eventParameters
            }
        }

        var type: LogType {
            switch self {
            case .searchError: return .severe
            default: return .analytic
            }
        }
    }
}

enum FocusField: Hashable {
    case searchBar
}
