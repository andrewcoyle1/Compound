import SwiftUI

@MainActor
protocol FoodLibraryRouter: GlobalRouter {
    func showIngredientAmountView(delegate: IngredientAmountDelegate)
    func showRecipeDetailView(delegate: RecipeDetailDelegate)
}

extension CoreRouter: FoodLibraryRouter { }
