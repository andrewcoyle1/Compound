import SwiftUI

struct FoodItemSearchDelegate {
    var onFoodSelected: ((FoodModel) -> Void)?
    var eventParameters: [String: Any]? { nil }
}

struct FoodItemSearchView: View {

    @State var presenter: FoodItemSearchPresenter
    let delegate: FoodItemSearchDelegate

    var body: some View {
        List {
            if !presenter.historyFoods.isEmpty && presenter.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                historySection
            }
            openFoodFactsSection
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

    private var historySection: some View {
        Section {
            ForEach(presenter.historyFoods) { food in
                foodRow(food)
            }
            .removeListRowFormatting()
        } header: {
            Text("Recent")
        }
    }

    @ViewBuilder
    private var openFoodFactsSection: some View {
        let trimmed = presenter.searchText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty || !presenter.openFoodFactsFoods.isEmpty {
            Section {
                if presenter.isSearching {
                    HStack(spacing: Spacing.s) {
                        ProgressView()
                        Text("Searching...")
                            .font(.rowDetail)
                            .foregroundStyle(.secondary)
                    }
                } else if presenter.searchFailed {
                    InlineMessage(.error, "Couldn't search right now")
                } else if presenter.openFoodFactsFoods.isEmpty && !trimmed.isEmpty {
                    ContentUnavailableView.search(text: trimmed)
                } else {
                    ForEach(presenter.openFoodFactsFoods) { food in
                        foodRow(food)
                    }
                    .removeListRowFormatting()
                }
            } header: {
                Text("Open Food Facts")
            }
        }
    }

    private func foodRow(_ food: FoodModel) -> some View {
        FoodLibraryPickerRowView(delegate: FoodLibraryPickerRowDelegate(
            item: food,
            onAdd: { delegate.onFoodSelected?(food) },
            onQuickAdd: { delegate.onFoodSelected?(food) }
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
