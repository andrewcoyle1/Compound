//
//  IngredientAmountPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/10/2025.
//

import Foundation

@Observable
@MainActor
class IngredientAmountPresenter {
    private let interactor: IngredientAmountInteractor
    private let router: IngredientAmountRouter

    var amountText: String = "100"

    /// What `amountText` is counted in: a serving unit such as a slice, or nil for grams/ml.
    ///
    /// Changing it rewrites the amount so it still means something: "1" of a serving unit, or
    /// back to grams/ml as the same quantity of food that was entered.
    var selectedUnit: ServingUnit? {
        didSet {
            guard selectedUnit != oldValue else { return }
            let previous = NutritionScaling.baseAmount(amountValue, in: oldValue)
            amountText = selectedUnit == nil ? String(format: "%g", NutritionScaling.rounded(previous)) : "1"
        }
    }

    func unitLabel(ingredient: FoodModel) -> String {
        selectedUnit?.name ?? ingredient.loggedUnitLabel
    }

    /// How much of the ingredient is being logged.
    ///
    /// `amountText` is a text field, so `"nan"` and `"inf"` are a few letters away. The
    /// `max(_, 0)` that used to floor `scale` filtered neither — see `Double.enteredAmount` — and
    /// the macro rows on this screen print `calories * scale` through `Int(_:)` while drawing, so
    /// the screen trapped as the letters were typed rather than showing a wrong number.
    var amountValue: Double { .enteredAmount(amountText) }
    var scale: Double { NutritionScaling.baseAmount(amountValue, in: selectedUnit) / 100.0 }
    func calories(ingredient: FoodModel) -> Double? { ingredient.calories.map { $0 * scale } }
    func protein(ingredient: FoodModel) -> Double? { ingredient.protein.map { $0 * scale } }
    func carbs(ingredient: FoodModel) -> Double? { ingredient.carbs.map { $0 * scale } }
    func fat(ingredient: FoodModel) -> Double? { ingredient.fatTotal.map { $0 * scale } }

    init(
        interactor: IngredientAmountInteractor,
        router: IngredientAmountRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    func add(ingredient: FoodModel, onConfirm: @escaping (MealItemModel) -> Void) {
        onConfirm(ingredient.mealItem(amount: amountValue, unit: selectedUnit))
    }

    func dismissScreen() {
        router.dismissScreen()
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif
}
