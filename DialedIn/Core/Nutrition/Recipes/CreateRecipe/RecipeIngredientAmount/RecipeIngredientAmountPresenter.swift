import Foundation

@Observable
@MainActor
class RecipeIngredientAmountPresenter {
    private let interactor: RecipeIngredientAmountInteractor
    private let router: RecipeIngredientAmountRouter

    var amountText: String = "100"

    /// How much of the food goes into the recipe. Sanitised for the reason given on
    /// `IngredientAmountPresenter.amountValue`: this screen prints `calories * scale` through
    /// `Int(_:)` from the view body, and the amount is stored on the recipe besides.
    var amountValue: Double { .enteredAmount(amountText) }
    var scale: Double { amountValue / 100.0 }

    init(interactor: RecipeIngredientAmountInteractor, router: RecipeIngredientAmountRouter) {
        self.interactor = interactor
        self.router = router
    }

    func unitLabel(food: FoodModel) -> String {
        food.measurementMethod == .volume ? String(localized: "ml") : String(localized: "g")
    }

    func calories(food: FoodModel) -> Double? { food.calories.map { $0 * scale } }
    func protein(food: FoodModel) -> Double? { food.protein.map { $0 * scale } }
    func carbs(food: FoodModel) -> Double? { food.carbs.map { $0 * scale } }
    func fat(food: FoodModel) -> Double? { food.fatTotal.map { $0 * scale } }

    func confirm(delegate: RecipeIngredientAmountDelegate) {
        let unit: IngredientAmountUnit = delegate.food.measurementMethod == .volume ? .milliliters : .grams
        let model = RecipeIngredientModel(ingredient: delegate.food, amount: amountValue, unit: unit)
        delegate.onConfirm(model)
        router.dismissScreen()
    }
}

@MainActor
protocol RecipeIngredientAmountInteractor: GlobalInteractor { }

@MainActor
protocol RecipeIngredientAmountRouter: GlobalRouter { }

extension CoreInteractor: RecipeIngredientAmountInteractor { }
extension CoreRouter: RecipeIngredientAmountRouter { }
