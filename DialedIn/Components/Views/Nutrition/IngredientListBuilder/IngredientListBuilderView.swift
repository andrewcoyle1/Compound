import SwiftUI

struct IngredientListBuilderDelegate {

    let mealItems: Binding<[MealItemModel]>?

    var onIngredientSelectionChanged: ((FoodModel) -> Void)?
    var onMealItemConfirmed: ((MealItemModel) -> Void)?
    var onRecipeIngredientConfirmed: ((RecipeIngredientModel) -> Void)?
    /// Optional list of ingredient templates that should display as "selected" in the UI.
    /// If `nil`, no selection state is shown.
    var selectedFoods: [FoodModel]?

    init(
        mealItems: Binding<[MealItemModel]>? = nil,
        onIngredientSelectionChanged: ((FoodModel) -> Void)? = nil,
        onMealItemConfirmed: ((MealItemModel) -> Void)? = nil,
        onRecipeIngredientConfirmed: ((RecipeIngredientModel) -> Void)? = nil,
        selectedFoods: [FoodModel]? = nil
    ) {
        self.mealItems = mealItems
        self.onIngredientSelectionChanged = onIngredientSelectionChanged
        self.onMealItemConfirmed = onMealItemConfirmed
        self.onRecipeIngredientConfirmed = onRecipeIngredientConfirmed
        self.selectedFoods = selectedFoods
    }
}

struct IngredientListBuilderView: View {
    
    @State var presenter: IngredientListBuilderPresenter
    
    let delegate: IngredientListBuilderDelegate
    
    var body: some View {
        List {
            if presenter.searchText.isEmpty {
                if !presenter.userFoods.isEmpty {
                    userFoodsSection
                }
                if !presenter.systemFoods.isEmpty {
                    systemFoodsSection
                }
            } else {
                filteredFoodsSection
            }
        }
        .overlay {
            if !presenter.searchText.isEmpty && presenter.filteredFoods.isEmpty {
                ContentUnavailableView.search(text: presenter.searchText)
            } else if presenter.searchText.isEmpty && presenter.userFoods.isEmpty && presenter.systemFoods.isEmpty {
                ContentUnavailableView {
                    Label("No Foods", systemImage: "carrot")
                } description: {
                    Text("Foods you create appear here.")
                } actions: {
                    Button("Create a Food") { presenter.onAddIngredientPressed(delegate: delegate) }
                }
            }
        }
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
        .scrollIndicators(.hidden)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presenter.onAddIngredientPressed(delegate: delegate)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add ingredient")
                .buttonStyle(.glassProminent)
            }
        }
    }
    
    private var userFoodsSection: some View {
        Section {
            ForEach(presenter.userFoods) { ingredient in
                FoodLibraryPickerRowView(
                    delegate: FoodLibraryPickerRowDelegate(
                        item: ingredient,
                        onAdd: {
                            presenter.navToIngredientAmountView(food: ingredient, delegate: delegate)
                        },
                        onQuickAdd: {
                            presenter.quickAdd(food: ingredient, delegate: delegate)
                        },
                        showImage: presenter.showFoodImageInLogger,
                        showCalories: presenter.showCaloriesInLogger,
                        showMacros: presenter.showMacrosInLogger,
                        showPortion: presenter.showPortionInLogger
                    )
                )
            }
        } header: {
            Text("Custom Foods")
        }
    }

    private var systemFoodsSection: some View {
        Section {
            ForEach(presenter.systemFoods) { ingredient in
                FoodLibraryPickerRowView(
                    delegate: FoodLibraryPickerRowDelegate(
                        item: ingredient,
                        onAdd: {
                            presenter.navToIngredientAmountView(food: ingredient, delegate: delegate)
                        },
                        onQuickAdd: {
                            presenter.quickAdd(food: ingredient, delegate: delegate)
                        },
                        showImage: presenter.showFoodImageInLogger,
                        showCalories: presenter.showCaloriesInLogger,
                        showMacros: presenter.showMacrosInLogger,
                        showPortion: presenter.showPortionInLogger
                    )
                )
            }
        } header: {
            Text("System Foods")
        }
    }

    private var filteredFoodsSection: some View {
        Section {
            ForEach(presenter.filteredFoods) { ingredient in
                FoodLibraryPickerRowView(
                    delegate: FoodLibraryPickerRowDelegate(
                        item: ingredient,
                        onAdd: {
                            presenter.navToIngredientAmountView(food: ingredient, delegate: delegate)
                        },
                        onQuickAdd: {
                            presenter.quickAdd(food: ingredient, delegate: delegate)
                        },
                        showImage: presenter.showFoodImageInLogger,
                        showCalories: presenter.showCaloriesInLogger,
                        showMacros: presenter.showMacrosInLogger,
                        showPortion: presenter.showPortionInLogger
                    )
                )
            }
        }
    }
}

extension CoreBuilder {
    
    func ingredientListBuilderView(router: AnyRouter, delegate: IngredientListBuilderDelegate) -> some View {
        IngredientListBuilderView(
            presenter: IngredientListBuilderPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showIngredientListBuilderView(delegate: IngredientListBuilderDelegate) {
        router.showScreen(.sheet) { router in
            builder.ingredientListBuilderView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = IngredientListBuilderDelegate()
    
    return RouterView { router in
        builder.ingredientListBuilderView(router: router, delegate: delegate)
    }
}
