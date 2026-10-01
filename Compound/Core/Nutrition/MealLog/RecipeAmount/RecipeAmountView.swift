//
//  RecipeAmountView.swift
//  Compound
//
//  Created by Andrew Coyle on 27/10/2025.
//

import SwiftUI

struct RecipeAmountDelegate {
    let recipe: RecipeTemplateModel
    let onPick: (MealItemModel) -> Void
}

struct RecipeAmountView: View {
    @State var presenter: RecipeAmountPresenter

    let delegate: RecipeAmountDelegate

    var body: some View {
        List {
            Section("Servings") {
                TextField("Servings", text: $presenter.servingsText)
                    .keyboardType(.decimalPad)
            }
            EstimatedMacrosSection(
                title: "Estimated Macros (per serving)",
                calories: presenter.baseCalories(recipe: delegate.recipe),
                protein: presenter.baseProtein(recipe: delegate.recipe),
                carbs: presenter.baseCarbs(recipe: delegate.recipe),
                fat: presenter.baseFat(recipe: delegate.recipe)
            )
        }
        .navigationTitle(delegate.recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add", role: .confirm) {
                    presenter.add(
                        recipe: delegate.recipe,
                        onConfirm: delegate.onPick
                    )
                }
                .disabled(presenter.servings <= 0)
            }
        }
    }
}

extension CoreBuilder {
    func recipeAmountView(router: AnyRouter, delegate: RecipeAmountDelegate) -> some View {
        RecipeAmountView(
            presenter: RecipeAmountPresenter(
                interactor: interactor,
                router: CoreRouter(
                    router: router,
                    builder: self
                )
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showRecipeAmountView(delegate: RecipeAmountDelegate) {
        router.showScreen(.push) { router in
            builder.recipeAmountView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.recipeAmountView(
            router: router, 
            delegate: RecipeAmountDelegate(
                recipe: RecipeTemplateModel.mock,
                onPick: { meal in
                    print(meal.id)
                }
            )
        )
    }
}
