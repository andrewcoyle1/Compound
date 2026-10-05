//
//  IngredientAmountPresenter.swift
//  Compound
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
            amountText = selectedUnit == nil ? NutritionScaling.rounded(previous).formatted(.number.grouping(.never)) : "1"
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

    private var hasStartedFromPortion = false

    /// Opens on the food's own portion, the one its row in the list and Quick Add describe, rather
    /// than a flat 100 g: rolled oats listed at "0.5 cup" used to open at 100 g. Once only, so
    /// coming back from the unit picker keeps what was typed.
    func onViewAppear(ingredient: FoodModel) {
        guard !hasStartedFromPortion else { return }
        hasStartedFromPortion = true
        let portion = ingredient.defaultPortion
        if let unit = portion.unit {
            selectedUnit = unit
            amountText = portion.amount.formatted(.number.grouping(.never))
        } else {
            amountText = NutritionScaling.rounded(portion.amount).formatted(.number.grouping(.never))
        }
    }

    /// Adds the food to the plate and returns to the list it was picked from, so a second tap on
    /// the same row cannot silently add a second copy.
    func add(ingredient: FoodModel, onConfirm: @escaping (MealItemModel) -> Void) {
        interactor.playHaptic(option: .success)
        onConfirm(ingredient.mealItem(amount: amountValue, unit: selectedUnit))
        router.dismissScreen()
    }

    /// Set once Log has put the food on the plate, so a second Log after a failed save logs the
    /// plate again without adding the food twice.
    private var hasAddedForLog = false

    /// Adds the food and logs the plate in one step. Logging closes the whole logger, this screen
    /// included; popping this screen as well started a second transition in the same instant and
    /// the system dropped the dismissal, leaving the logger open over a logged meal.
    func log(ingredient: FoodModel, onConfirm: (MealItemModel) -> Void, onLog: () -> Void) {
        if !hasAddedForLog {
            hasAddedForLog = true
            onConfirm(ingredient.mealItem(amount: amountValue, unit: selectedUnit))
        }
        onLog()
    }

    func dismissScreen() {
        router.dismissScreen()
    }

}
