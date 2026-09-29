import SwiftUI

@Observable
@MainActor
class FoodLibraryPresenter {
    
    private let interactor: FoodLibraryInteractor
    private let router: FoodLibraryRouter
    
    var foodLibraryOption: FoodLibraryOption = .recipes

    /// Filters the favourites list. The recipes and foods tabs are child views with their own
    /// search, so this only applies to the tab drawn here.
    var searchText: String = ""

    init(interactor: FoodLibraryInteractor, router: FoodLibraryRouter) {
        self.interactor = interactor
        self.router = router
    }

    var searchPrompt: String {
        switch foodLibraryOption {
        case .recipes:      return String(localized: "Filter Recipes")
        case .foods:        return String(localized: "Filter Foods")
        case .favourites:   return String(localized: "Filter Favourites")
        }
    }

    /// Favourited recipes, resolved from the ids stored on the food log settings. Ids whose recipe
    /// has since been deleted are dropped rather than shown as blank rows.
    var favouriteRecipes: [RecipeTemplateModel] {
        let ids = Set(interactor.foodLogSettings.favouriteRecipeIds)
        return matching(interactor.userRecipeTemplates.filter { ids.contains($0.id) }) { $0.name }
    }

    var favouriteFoods: [FoodModel] {
        let ids = Set(interactor.foodLogSettings.favouriteFoodIds)
        return matching(interactor.foods.filter { ids.contains($0.id) }) { $0.name }
    }

    var hasFavourites: Bool {
        !interactor.foodLogSettings.favouriteRecipeIds.isEmpty
            || !interactor.foodLogSettings.favouriteFoodIds.isEmpty
    }

    private func matching<T>(_ items: [T], name: (T) -> String) -> [T] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = query.isEmpty ? items : items.filter { name($0).lowercased().contains(query) }
        return filtered.sorted { name($0) < name($1) }
    }
    
    /// Same destination the search and barcode tabs use, so a favourite is logged with the amount
    /// step rather than being added at some assumed quantity — unless Quick Add is on, in which
    /// case it takes the same shortcut those tabs take.
    func onFavouriteFoodPressed(_ food: FoodModel, onPick: ((MealItemModel) -> Void)?) {
        if interactor.foodLogSettings.quickAddEnabled {
            onPick?(food.mealItem(amount: food.defaultPortionAmount))
            return
        }
        router.showIngredientAmountView(
            delegate: IngredientAmountDelegate(
                ingredient: food,
                onPick: { item in onPick?(item) }
            )
        )
    }

    func onFavouriteRecipePressed(_ recipe: RecipeTemplateModel) {
        router.showRecipeDetailView(delegate: RecipeDetailDelegate(recipeTemplate: recipe))
    }

    /// The plate is assembled in the parent screen, so committing it is simply leaving the picker.
    func onLogFoodsPressed() {
        router.dismissScreen()
    }

    func onViewAppear(delegate: FoodLibraryDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: FoodLibraryDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
}

extension FoodLibraryPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: FoodLibraryDelegate)
        case onDisappear(delegate: FoodLibraryDelegate)
        
        var eventName: String {
            switch self {
            case .onAppear:                 return "FoodLibraryView_Appear"
            case .onDisappear:              return "FoodLibraryView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
                //            default:
                //                return nil
            }
        }
        
        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }
    
}
