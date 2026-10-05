import SwiftUI

struct FoodItemSearchDelegate {
    var onFoodSelected: ((FoodModel) -> Void)?
    /// The row's "+": onto the plate without the amount screen. Falls back to `onFoodSelected`.
    var onFoodQuickAdded: ((FoodModel) -> Void)?
    var onRecipeSelected: ((RecipeTemplateModel) -> Void)?
    var onRecipeQuickAdded: ((RecipeTemplateModel) -> Void)?
    /// The plate's current items, so a row can show how many of this food are already on it.
    var mealItems: Binding<[MealItemModel]>?
    var eventParameters: [String: Any]? { nil }
}

struct FoodItemSearchView: View {

    @State var presenter: FoodItemSearchPresenter
    let delegate: FoodItemSearchDelegate

    /// Searching is what this screen is for, so the field opens focused with the keyboard up.
    @State private var isSearchPresented = false

    var body: some View {
        List {
            if trimmedQuery.isEmpty {
                if presenter.history.isEmpty {
                    ContentUnavailableView {
                        Label("Search Foods", systemImage: Symbol.search)
                    } description: {
                        Text("Find foods you've saved and packaged foods from Open Food Facts.")
                    }
                } else {
                    historySection
                }
            } else {
                librarySection
                recipeSection
                if presenter.searchesOnline {
                    openFoodFactsSection
                } else if presenter.libraryResults.isEmpty, presenter.recipeResults.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                }
            }
        }
        .searchable(text: $presenter.searchText, isPresented: $isSearchPresented, placement: .toolbar, prompt: Text("Search foods"))
        .onChange(of: presenter.searchText) { _, newValue in
            presenter.onSearchTextChanged(newValue)
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
            // Not when coming back from the amount screen with a query still showing its results.
            if presenter.searchText.isEmpty { isSearchPresented = true }
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    private var trimmedQuery: String {
        presenter.searchText.trimmingCharacters(in: .whitespaces)
    }

    @ViewBuilder
    private var librarySection: some View {
        if !presenter.libraryResults.isEmpty {
            Section {
                ForEach(presenter.libraryResults) { food in
                    foodRow(food)
                }
            } header: {
                Text("My Foods")
            }
        }
    }

    @ViewBuilder
    private var recipeSection: some View {
        if !presenter.recipeResults.isEmpty, delegate.onRecipeSelected != nil {
            Section {
                ForEach(presenter.recipeResults) { recipe in
                    recipeRow(recipe)
                }
            } header: {
                Text("My Recipes")
            }
        }
    }

    private func recipeRow(_ recipe: RecipeTemplateModel) -> some View {
        let settings = presenter.tileSettings
        return FoodLibraryPickerRowView(delegate: FoodLibraryPickerRowDelegate(
            item: recipe,
            onAdd: { delegate.onRecipeSelected?(recipe) },
            onQuickAdd: { (delegate.onRecipeQuickAdded ?? delegate.onRecipeSelected)?(recipe) },
            showImage: settings.showFoodImageInLogger,
            showCalories: settings.showCaloriesInLogger,
            showMacros: settings.showMacrosInLogger,
            showPortion: settings.showPortionInLogger,
            addedCount: delegate.mealItems?.wrappedValue.addedCount(forRecipeId: recipe.recipeId) ?? 0
        ))
    }

    private var historySection: some View {
        Section {
            ForEach(presenter.history) { pick in
                switch pick {
                case .food(let food):
                    foodRow(food)
                case .recipe(let recipe):
                    if delegate.onRecipeSelected != nil { recipeRow(recipe) }
                }
            }
        } header: {
            Text("Recent")
        }
    }

    private var openFoodFactsSection: some View {
        Section {
            if presenter.isSearching {
                HStack(spacing: Spacing.s) {
                    ProgressView()
                    Text("Searching…")
                        .font(.rowDetail)
                        .foregroundStyle(.secondary)
                }
            } else if presenter.searchFailedOffline {
                InlineMessage(.warning, "You're offline. Showing your library only.")
            } else if presenter.searchFailed {
                InlineMessage(.error, "Couldn't search right now")
            } else if presenter.onlineResults.isEmpty {
                if presenter.libraryResults.isEmpty, presenter.recipeResults.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                }
            } else {
                ForEach(presenter.onlineResults) { food in
                    foodRow(food)
                }
            }
        } header: {
            Text("Open Food Facts")
        }
    }

    private func foodRow(_ food: FoodModel) -> some View {
        let settings = presenter.tileSettings
        return FoodLibraryPickerRowView(delegate: FoodLibraryPickerRowDelegate(
            item: food,
            onAdd: { delegate.onFoodSelected?(food) },
            onQuickAdd: { (delegate.onFoodQuickAdded ?? delegate.onFoodSelected)?(food) },
            showImage: settings.showFoodImageInLogger,
            showCalories: settings.showCaloriesInLogger,
            showMacros: settings.showMacrosInLogger,
            showPortion: settings.showPortionInLogger,
            addedCount: delegate.mealItems?.wrappedValue.addedCount(forIngredientId: food.ingredientId) ?? 0
        ))
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = FoodItemSearchDelegate()

    return RouterView { router in
        builder.foodItemSearchView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func foodItemSearchView(router: AnyRouter, delegate: FoodItemSearchDelegate) -> some View {
        FoodItemSearchView(
            presenter: FoodItemSearchPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showFoodItemSearchView(delegate: FoodItemSearchDelegate) {
        router.showScreen(.push) { router in
            builder.foodItemSearchView(router: router, delegate: delegate)
        }
    }

}
