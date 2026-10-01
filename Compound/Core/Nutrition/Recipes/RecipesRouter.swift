//
//  RecipesRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol RecipesRouter {
    func showRecipeDetailView(delegate: RecipeDetailDelegate)
    func showSimpleAlert(title: String, subtitle: String?)
    
    func showCreateRecipeView()
}

extension CoreRouter: RecipesRouter { }
