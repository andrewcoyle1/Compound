//
//  RecipeDetailRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol RecipeDetailRouter: GlobalRouter {
    func showStartRecipeView(delegate: RecipeStartDelegate)
}

extension CoreRouter: RecipeDetailRouter { }
