//
//  CreateRecipeRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol CreateRecipeRouter: GlobalRouter {
    func showIngredientListBuilderView(delegate: IngredientListBuilderDelegate)
    func showRecipePreparationView(delegate: RecipePreparationDelegate)
}

extension CoreRouter: CreateRecipeRouter { }
