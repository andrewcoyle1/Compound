//
//  RecipeStartView.swift
//  Compound
//
//  Created by Andrew Coyle on 27/09/2025.
//

import SwiftUI

struct RecipeStartView: View {

    @State var presenter: RecipeStartPresenter

    var delegate: RecipeStartDelegate

    var body: some View {
        List {
            Section("Ingredients") {
                ForEach(delegate.recipe.ingredients) { wrapper in
                    LabeledContent(wrapper.ingredient.name, value: "\(wrapper.amount.formatted(.number.precision(.fractionLength(0...1)))) \(unitString(wrapper.unit))")
                        .monospacedDigit()
                }
            }
        }
        .navigationTitle(delegate.recipe.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    private func unitString(_ unit: IngredientAmountUnit) -> String {
        switch unit {
        case .grams: return "g"
        case .milliliters: return "ml"
        case .units: return "units"
        }
    }
}

extension CoreBuilder {
    func recipeStartView(router: AnyRouter, delegate: RecipeStartDelegate) -> some View {
        RecipeStartView(
            presenter: RecipeStartPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showStartRecipeView(delegate: RecipeStartDelegate) {
        router.showScreen(.push) { router in
            builder.recipeStartView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    RouterView { router in
        builder.recipeStartView(router: router, delegate: RecipeStartDelegate(recipe: .mock))
    }
}
