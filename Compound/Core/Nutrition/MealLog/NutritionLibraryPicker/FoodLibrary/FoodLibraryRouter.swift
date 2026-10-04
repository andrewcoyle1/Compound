import SwiftUI

@MainActor
protocol FoodLibraryRouter: GlobalRouter {
    func showIngredientAmountView(delegate: IngredientAmountDelegate)
    func showRecipeDetailView(delegate: RecipeDetailDelegate)
    func showRecipeAmountView(delegate: RecipeAmountDelegate)
}

extension CoreRouter: FoodLibraryRouter { }
