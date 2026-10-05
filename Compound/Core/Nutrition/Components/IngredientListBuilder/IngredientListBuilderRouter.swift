import SwiftUI

@MainActor
protocol IngredientListBuilderRouter: GlobalRouter {
    func showCreateFoodView(delegate: CreateFoodDelegate)
    func showIngredientAmountView(delegate: IngredientAmountDelegate)
    func showRecipeIngredientAmountView(delegate: RecipeIngredientAmountDelegate)
}

extension CoreRouter: IngredientListBuilderRouter { }
