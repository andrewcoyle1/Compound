import SwiftUI

struct FoodItemSearchDelegate {
    var onFoodSelected: ((FoodModel) -> Void)?
    /// The plate's current items, so a row can show how many of this food are already on it.
    var mealItems: Binding<[MealItemModel]>?
    var eventParameters: [String: Any]? { nil }
}

struct FoodItemSearchView: View {

    @State var presenter: FoodItemSearchPresenter
    let delegate: FoodItemSearchDelegate

    var body: some View {
        List {
            if trimmedQuery.isEmpty {
                if presenter.historyFoods.isEmpty {
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
                if presenter.searchesOnline {
                    openFoodFactsSection
                } else if presenter.libraryResults.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                }
            }
        }
        .searchable(text: $presenter.searchText, placement: .toolbar, prompt: Text("Search foods"))
        .onChange(of: presenter.searchText) { _, newValue in
            presenter.onSearchTextChanged(newValue)
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
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

    private var historySection: some View {
        Section {
            ForEach(presenter.historyFoods) { food in
                foodRow(food)
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
                if presenter.libraryResults.isEmpty {
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
            onQuickAdd: { delegate.onFoodSelected?(food) },
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
