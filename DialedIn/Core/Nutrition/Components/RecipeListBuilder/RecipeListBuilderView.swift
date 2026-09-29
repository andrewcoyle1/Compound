import SwiftUI

struct RecipeListBuilderDelegate {
    var onRecipeSelectionChanged: ((RecipeTemplateModel) -> Void)?
    var onMealItemConfirmed: ((MealItemModel) -> Void)?
    /// Optional list of recipe templates that should display as "selected" in the UI.
    /// If `nil`, no selection state is shown.
    var selectedRecipeTemplates: [RecipeTemplateModel]?
    /// A query typed into a search field the host owns. `nil` means the list shows its own.
    var searchText: String?
}

struct RecipeListBuilderView: View {
    
    @State var presenter: RecipeListBuilderPresenter
    
    let delegate: RecipeListBuilderDelegate
    
    private func isRecipeTemplateSelected(_ recipeTemplate: RecipeTemplateModel) -> Bool {
        delegate.selectedRecipeTemplates?.contains(recipeTemplate) ?? false
    }

    /// Nothing ever set `searchText`, so the filtered list and its empty state could not appear.
    /// Standalone, the list now has its own search field; inside the food library it follows the
    /// library's.
    var body: some View {
        if delegate.searchText == nil {
            list.searchable(text: $presenter.searchText, placement: .toolbar, prompt: Text("Filter Recipes"))
        } else {
            list
        }
    }

    private var list: some View {
        List {
            if presenter.searchText.isEmpty {
                if !presenter.userRecipeTemplates.isEmpty {
                    userRecipeTemplatesSection
                }
                if !presenter.systemRecipeTemplates.isEmpty {
                    systemRecipeTemplatesSection
                }
            } else {
                filteredRecipeTemplatesSection
            }
        }
        .overlay {
            if !presenter.searchText.isEmpty && presenter.filteredRecipeTemplates.isEmpty {
                ContentUnavailableView.search(text: presenter.searchText)
            } else if presenter.searchText.isEmpty && presenter.userRecipeTemplates.isEmpty && presenter.systemRecipeTemplates.isEmpty {
                ContentUnavailableView {
                    Label("No Recipes", systemImage: Symbol.recipe)
                } description: {
                    Text("Recipes you create appear here.")
                } actions: {
                    Button("Create a Recipe") { presenter.onAddRecipePressed() }
                }
            }
        }
        .onChange(of: delegate.searchText, initial: true) { _, newValue in
            if let newValue { presenter.searchText = newValue }
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
                    presenter.onAddRecipePressed()
                } label: {
                    Image(systemName: Symbol.add)
                        .foregroundStyle(.onAccent)
                }
                .accessibilityLabel("Add recipe")
                .buttonStyle(.glassProminent)
            }
        }
    }
    
    // MARK: UI Components
    private var userRecipeTemplatesSection: some View {
        Section {
            ForEach(presenter.userRecipeTemplates) { recipe in
                recipeRow(recipe)
            }
        } header: {
            Text("Custom Recipes")
        }
    }

    private var systemRecipeTemplatesSection: some View {
        Section {
            ForEach(presenter.systemRecipeTemplates) { recipe in
                recipeRow(recipe)
            }
        } header: {
            Text("System Recipes")
        }
    }

    private var filteredRecipeTemplatesSection: some View {
        Section {
            ForEach(presenter.filteredRecipeTemplates) { recipe in
                recipeRow(recipe)
            }
        }
    }

    @ViewBuilder
    private func recipeRow(_ recipe: RecipeTemplateModel) -> some View {
        if delegate.onMealItemConfirmed != nil {
            FoodLibraryPickerRowView(
                delegate: FoodLibraryPickerRowDelegate(
                    item: recipe,
                    onAdd: {
                        presenter.navToRecipeAmountView(recipe: recipe, delegate: delegate)
                    },
                    onQuickAdd: {
                        presenter.quickAdd(recipe: recipe, delegate: delegate)
                    },
                    showImage: presenter.showFoodImageInLogger,
                    showCalories: presenter.showCaloriesInLogger,
                    showMacros: presenter.showMacrosInLogger,
                    showPortion: presenter.showPortionInLogger
                )
            )
        } else {
            Button {
                delegate.onRecipeSelectionChanged?(recipe)
            } label: {
                ListRow(
                    title: recipe.name,
                    subtitle: recipe.description,
                    imageName: recipe.imageURL,
                    accessory: delegate.selectedRecipeTemplates == nil ? .chevron : .checkmark(isRecipeTemplateSelected(recipe))
                )
                .contentShape(.rect)
            }
        }
    }
}

extension CoreBuilder {
    
    func recipeListBuilderView(router: AnyRouter, delegate: RecipeListBuilderDelegate) -> some View {
        RecipeListBuilderView(
            presenter: RecipeListBuilderPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showRecipeListBuilderView(delegate: RecipeListBuilderDelegate) {
        router.showScreen(.push) { router in
            builder.recipeListBuilderView(router: router, delegate: delegate)
        }
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    let delegate = RecipeListBuilderDelegate()
    
    return RouterView { router in
        builder.recipeListBuilderView(router: router, delegate: delegate)
    }
}
