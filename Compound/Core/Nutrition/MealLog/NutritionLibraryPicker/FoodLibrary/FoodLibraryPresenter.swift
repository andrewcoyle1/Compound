import SwiftUI

@Observable
@MainActor
class FoodLibraryPresenter {
    
    private let interactor: FoodLibraryInteractor
    private let router: FoodLibraryRouter
    
    var foodLibraryOption: FoodLibraryOption

    /// The query in the library's search field. It filters the favourites drawn here and is handed
    /// to the recipes and foods lists, which had no search of their own despite this comment
    /// saying so.
    var searchText: String = ""

    init(interactor: FoodLibraryInteractor, router: FoodLibraryRouter) {
        self.interactor = interactor
        self.router = router
        // Favourites are what the user keeps coming back to, so they open first once there are any.
        let settings = interactor.foodLogSettings
        self.foodLibraryOption = settings.favouriteFoodIds.isEmpty && settings.favouriteRecipeIds.isEmpty
            ? .recipes
            : .favourites
    }

    var searchPrompt: String {
        switch foodLibraryOption {
        case .recipes:      return String(localized: "Filter Recipes")
        case .foods:        return String(localized: "Filter Foods")
        case .favourites:   return String(localized: "Filter Favorites")
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
    func onFavouriteFoodPressed(_ food: FoodModel, onPick: ((MealItemModel) -> Void)?, onLog: (() -> Void)? = nil) {
        if interactor.foodLogSettings.quickAddEnabled {
            interactor.playHaptic(option: .success)
            onPick?(food.quickAddItem(lastLoggedIn: interactor.userMeals))
            return
        }
        router.showIngredientAmountView(
            delegate: IngredientAmountDelegate(
                ingredient: food,
                onPick: { item in onPick?(item) },
                onLog: onLog
            )
        )
    }

    /// While logging, a favourite recipe goes to its servings, as every other recipe row does;
    /// it used to open the recipe's page, which has no way to log it. Elsewhere, the page.
    func onFavouriteRecipePressed(_ recipe: RecipeTemplateModel, onPick: ((MealItemModel) -> Void)? = nil, onLog: (() -> Void)? = nil) {
        guard let onPick else {
            router.showRecipeDetailView(delegate: RecipeDetailDelegate(recipeTemplate: recipe))
            return
        }
        router.showRecipeAmountView(delegate: RecipeAmountDelegate(recipe: recipe, onPick: onPick, onLog: onLog))
    }

    /// The prompt and the list both change with the tab; a stale query would filter the new list
    /// by something the user typed for the old one.
    func onLibraryOptionChanged() {
        interactor.playHaptic(option: .selection)
        searchText = ""
    }
}
