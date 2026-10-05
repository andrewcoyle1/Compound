//
//  RecipeAmountPresenter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/10/2025.
//

import Foundation

@Observable
@MainActor
class RecipeAmountPresenter {
    private let interactor: RecipeAmountInteractor
    private let router: RecipeAmountRouter

    var servingsText: String = "1"

    /// How many servings were eaten.
    ///
    /// `servingsText` is a text field, so `"nan"` and `"inf"` are three and three letters away.
    /// The `max(parsed, 0)` this used to be filtered neither — see `Double.enteredAmount` — and
    /// from here the figure multiplies into every nutrient logged for the meal, which the meal-log
    /// rows print through `Int(_:)` and which is written to the meal document besides.
    var servings: Double { .enteredAmount(servingsText) }

    init(
        interactor: RecipeAmountInteractor,
        router: RecipeAmountRouter
    ) {
        self.interactor = interactor
        self.router = router
    }

    /// A per-serving figure for the servings entered.
    func forServings(_ perServing: Double?) -> Double? {
        perServing.map { $0 * servings }
    }

    func baseCalories(recipe: RecipeTemplateModel) -> Double? {
        NutritionScaling.perServing(recipe)[.calories]
    }

    func baseProtein(recipe: RecipeTemplateModel) -> Double? {
        NutritionScaling.perServing(recipe)[.protein]
    }

    func baseCarbs(recipe: RecipeTemplateModel) -> Double? {
        NutritionScaling.perServing(recipe)[.carbs]
    }

    func baseFat(recipe: RecipeTemplateModel) -> Double? {
        NutritionScaling.perServing(recipe)[.fatTotal]
    }

    func add(recipe: RecipeTemplateModel, onConfirm: @escaping (MealItemModel) -> Void) {
        interactor.playHaptic(option: .success)
        onConfirm(recipe.mealItem(servings: servings))
        router.dismissScreen()
    }

    /// Set once Log has put the recipe on the plate, so a second Log after a failed save does not
    /// add it twice.
    private var hasAddedForLog = false

    /// Adds the recipe and logs the plate in one step; logging closes the logger, this screen
    /// with it.
    func log(recipe: RecipeTemplateModel, onConfirm: (MealItemModel) -> Void, onLog: () -> Void) {
        if !hasAddedForLog {
            hasAddedForLog = true
            onConfirm(recipe.mealItem(servings: servings))
        }
        onLog()
    }
}
