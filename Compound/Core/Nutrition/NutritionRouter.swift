//
//  NutritionRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol NutritionRouter: GlobalRouter {
    func showAddMealView(delegate: AddMealDelegate)
    func showMealDetailView(delegate: MealDetailDelegate)
    func showMealItemAmountViewView(delegate: MealItemAmountViewDelegate)
    func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID)

    func showTimelineActionsView(delegate: TimelineActionsDelegate)
    func showFoodLogSettingsView(delegate: FoodLogSettingsDelegate)
    func showNutritionOverviewView(delegate: NutritionOverviewDelegate)
    func showFoodsView()
    func showRecipesView()
    func showFoodDetailView(delegate: FoodDetailDelegate)
    func showRecipeDetailView(delegate: RecipeDetailDelegate)
}

extension CoreRouter: NutritionRouter { }
