//
//  RecipeAmountPresenter.swift
//  DialedIn
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
        // Per serving first, then by how many servings were eaten. Scaling the whole recipe by the
        // servings instead logged the entire pot for every serving — a four-serving dish went in
        // at four times what was eaten.
        let scaledNutrients = NutritionScaling.nutrients(of: recipe)
            .scaled(by: NutritionScaling.factor(servings: servings, of: recipe))
        let item = MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .recipe,
            sourceId: recipe.recipeId,
            displayName: recipe.name,
            amount: servings,
            unit: "serving",
            resolvedGrams: nil,
            resolvedMilliliters: nil,
            nutrients: scaledNutrients
        )
        onConfirm(item)
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif
}
