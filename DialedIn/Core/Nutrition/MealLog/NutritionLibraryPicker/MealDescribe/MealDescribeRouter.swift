import SwiftUI

@MainActor
protocol MealDescribeRouter: GlobalRouter {
    func showIngredientAmountView(delegate: IngredientAmountDelegate)
}

extension CoreRouter: MealDescribeRouter { }
