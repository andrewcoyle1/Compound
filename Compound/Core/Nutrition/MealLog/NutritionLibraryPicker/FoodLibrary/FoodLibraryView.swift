import SwiftUI

struct FoodLibraryDelegate {
    
    let mealItems: Binding<[MealItemModel]>
    let onItemPick: ((MealItemModel) -> Void)?
    /// The plate's Log, handed on to the amount screens.
    let onLog: (() -> Void)?

    init(
        mealItems: Binding<[MealItemModel]>,
        onItemPick: ((MealItemModel) -> Void)? = nil,
        onLog: (() -> Void)? = nil
    ) {
        self.mealItems = mealItems
        self.onItemPick = onItemPick
        self.onLog = onLog
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
            ContentUnavailableView {
                Label("No Favorites", systemImage: "heart")
            } description: {
                Text("Tap the heart on a food or recipe to keep it here.")
            }
        } else {
            List {
                if !presenter.favouriteRecipes.isEmpty {
                    Section {
                        ForEach(presenter.favouriteRecipes) { recipe in
                            Button {
                                presenter.onFavouriteRecipePressed(recipe, onPick: delegate.onItemPick, onLog: delegate.onLog)
                            } label: {
                                ListRow(title: recipe.name, subtitle: recipe.description, imageName: recipe.imageURL, accessory: .chevron)
                                    .contentShape(.rect)
                            }
                        }
                    } header: {
                        Text("Recipes")
                    }
                }

                if !presenter.favouriteFoods.isEmpty {
                    Section {
                        ForEach(presenter.favouriteFoods) { food in
                            Button {
                                presenter.onFavouriteFoodPressed(food, onPick: delegate.onItemPick, onLog: delegate.onLog)
                            } label: {
                                ListRow(title: food.name, subtitle: food.description, imageName: food.imageURL, accessory: .chevron)
                                    .contentShape(.rect)
                            }
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
                        onMealItemConfirmed: { item in delegate.onItemPick?(item) },
                        onLog: delegate.onLog,
                        mealItems: delegate.mealItems,
                        searchText: presenter.searchText
                    )
                )
            case .foods:
                ingredientList(
                    IngredientListBuilderDelegate(
                        mealItems: delegate.mealItems,
                        onMealItemConfirmed: { item in delegate.onItemPick?(item) },
                        searchText: presenter.searchText,
                        onLog: delegate.onLog,
                        isEmbedded: true
                    )
                )
            case .favourites:
                favouritesList
            }
        }
        .safeAreaBar(edge: .top) {
            Picker("Library", selection: $presenter.foodLibraryOption) {
                ForEach(FoodLibraryOption.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, Spacing.s)
        }
        .searchable(text: $presenter.searchText, placement: .toolbar, prompt: Text(presenter.searchPrompt))
        .onChange(of: presenter.foodLibraryOption) {
            presenter.onLibraryOptionChanged()
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
        case .favourites: return String(localized: "Favorites")
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
