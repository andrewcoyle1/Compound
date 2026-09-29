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

    var searchText: String = ""

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
