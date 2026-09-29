import SwiftUI

struct FoodLibraryDelegate {
    
    let mealItems: Binding<[MealItemModel]>
    let onItemPick: ((MealItemModel) -> Void)?
    
    init(
        mealItems: Binding<[MealItemModel]>,
        onItemPick: ((MealItemModel) -> Void)? = nil
    ) {
        self.mealItems = mealItems
        self.onItemPick = onItemPick
    }
    
    var eventParameters: [String: Any]? {
        nil
    }
}

struct FoodLibraryView<
    RecipeList: View,
    IngredientList: View
>: View {
    
    @State var presenter: FoodLibraryPresenter
    let delegate: FoodLibraryDelegate
    
    @ViewBuilder var recipeList: (RecipeListBuilderDelegate) -> RecipeList
    @ViewBuilder var ingredientList: (IngredientListBuilderDelegate) -> IngredientList

    @ViewBuilder
    private var favouritesList: some View {
        if !presenter.hasFavourites {
            ContentUnavailableView(
                "No Favourites",
                systemImage: "heart",
                description: Text("Tap the heart on a food or recipe to keep it here.")
            )
        } else {
            List {
                if !presenter.favouriteRecipes.isEmpty {
                    Section {
                        ForEach(presenter.favouriteRecipes) { recipe in
                            CustomListCellView(
                                imageName: recipe.imageURL,
                                title: recipe.name,
                                subtitle: recipe.description
                            )
                            .anyButton(.highlight) {
                                presenter.onFavouriteRecipePressed(recipe)
                            }
                            .removeListRowFormatting()
                        }
                    } header: {
                        Text("Recipes")
                    }
                }

                if !presenter.favouriteFoods.isEmpty {
                    Section {
                        ForEach(presenter.favouriteFoods) { food in
                            CustomListCellView(
                                imageName: food.imageURL,
                                title: food.name,
                                subtitle: food.description
                            )
                            .anyButton(.highlight) {
                                presenter.onFavouriteFoodPressed(food, onPick: delegate.onItemPick)
                            }
                            .removeListRowFormatting()
                        }
                    } header: {
                        Text("Foods")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    var body: some View {
        Group {
            switch presenter.foodLibraryOption {
            case .recipes:
                recipeList(
                    RecipeListBuilderDelegate(
                        onMealItemConfirmed: { item in delegate.onItemPick?(item) }
                    )
                )
            case .foods:
                ingredientList(
                    IngredientListBuilderDelegate(
                        mealItems: delegate.mealItems,
                        onMealItemConfirmed: { item in delegate.onItemPick?(item) }
                    )
                )
            case .favourites:
                favouritesList
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Picker(selection: $presenter.foodLibraryOption) {
                    ForEach(FoodLibraryOption.allCases, id: \.self) { option in
                        option.icon.tag(option)
                    }
                } label: {
                    Text("Picker")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
                Spacer()
            }
            .padding()
        }
        .searchable(text: $presenter.searchText, prompt: presenter.searchPrompt)
        .toolbar {
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button {
                    presenter.onLogFoodsPressed()
                } label: {
                    Text("Log Foods")
                }
                .buttonStyle(.glassProminent)
                .disabled(delegate.mealItems.wrappedValue.isEmpty)
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onChange(of: presenter.foodLibraryOption) {
            // The prompt and the list both change with the tab; a stale query would filter the
            // new list by something the user typed for the old one.
            presenter.searchText = ""
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
}

enum FoodLibraryOption: String, CaseIterable, Hashable, Identifiable {
    var id: String { self.rawValue }
    case recipes
    case foods
    case favourites
    
    var title: String {
        switch self {
        case .recipes: return String(localized: "Recipes")
        case .foods: return String(localized: "Foods")
        case .favourites: return String(localized: "Favourites")
        }
    }
    
    @MainActor
    var icon: some View {
        switch self {
        case .recipes: return Text("Recipes").any()
        case .foods: return Text("Foods").any()
        case .favourites: return Image(systemName: "heart.fill").any()
        }
    }
}

#Preview {
    @Previewable @State var mealItems: [MealItemModel] = MealItemModel.mocks
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = FoodLibraryDelegate(mealItems: $mealItems)
    
    RouterView { router in
        builder.foodLibraryView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func foodLibraryView(router: AnyRouter, delegate: FoodLibraryDelegate) -> some View {
        FoodLibraryView(
            presenter: FoodLibraryPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate,
            recipeList: { recipeListDelegate in
                self.recipeListBuilderView(router: router, delegate: recipeListDelegate)
            },
            ingredientList: { ingredientDelegate in
                self.ingredientListBuilderView(router: router, delegate: ingredientDelegate)
            }
        )
    }
    
}

extension CoreRouter {
    
    func showFoodLibraryView(delegate: FoodLibraryDelegate) {
        router.showScreen(.push) { router in
            builder.foodLibraryView(router: router, delegate: delegate)
        }
    }
    
}
