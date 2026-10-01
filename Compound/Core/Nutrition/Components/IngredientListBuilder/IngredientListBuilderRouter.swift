import SwiftUI

@MainActor
protocol IngredientListBuilderRouter: GlobalRouter {
    func showCreateFoodView(delegate: CreateFoodDelegate)
    func showMealItemAmountViewView(delegate: MealItemAmountViewDelegate)
    func showRecipeIngredientAmountView(delegate: RecipeIngredientAmountDelegate)
}

extension CoreRouter: IngredientListBuilderRouter { }
