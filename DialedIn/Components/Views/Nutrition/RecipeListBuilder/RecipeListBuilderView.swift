import SwiftUI

struct RecipeListBuilderDelegate {
    var onRecipeSelectionChanged: ((RecipeTemplateModel) -> Void)?
    var onMealItemConfirmed: ((MealItemModel) -> Void)?
    /// Optional list of recipe templates that should display as "selected" in the UI.
    /// If `nil`, no selection state is shown.
    var selectedRecipeTemplates: [RecipeTemplateModel]?
}

struct RecipeListBuilderView: View {
    
    @State var presenter: RecipeListBuilderPresenter
    
    let delegate: RecipeListBuilderDelegate
    
    private func isRecipeTemplateSelected(_ recipeTemplate: RecipeTemplateModel) -> Bool {
        delegate.selectedRecipeTemplates?.contains(recipeTemplate) ?? false
    }

    var body: some View {
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
                    Label("No Recipes", systemImage: "book.closed")
                } description: {
                    Text("Recipes you create appear here.")
                } actions: {
                    Button("Create a Recipe") { presenter.onAddRecipePressed() }
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
                    presenter.onAddRecipePressed()
                } label: {
                    Image(systemName: "plus")
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
            CustomListCellView(
                imageName: recipe.imageURL,
                title: recipe.name,
                subtitle: recipe.description,
                isSelected: isRecipeTemplateSelected(recipe)
            )
            .anyButton(.highlight) {
                delegate.onRecipeSelectionChanged?(recipe)
            }
            .removeListRowFormatting()
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
