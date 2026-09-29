import SwiftUI

@MainActor
protocol RecipeListBuilderRouter: GlobalRouter {
    func showRecipeDetailView(delegate: RecipeDetailDelegate)
    func showCreateRecipeView()
    func showRecipeAmountView(delegate: RecipeAmountDelegate)
}

extension CoreRouter: RecipeListBuilderRouter { }
