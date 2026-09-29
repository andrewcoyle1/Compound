//
//  CreateRecipePresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/10/2025.
//

import SwiftUI

@Observable
@MainActor
class CreateRecipePresenter {
    private let interactor: CreateRecipeInteractor
    private let router: CreateRecipeRouter

    var recipeName: String = ""
    var servingQuantity: Double?
    var recipeTotalWeight: Double?
    var showAllNutrition: Bool = false
    
    var ingredients: [RecipeIngredientModel] = []

    var currentUser: UserModel? {
        interactor.currentUser
    }
    
    var canSave: Bool {
        !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        interactor: CreateRecipeInteractor,
        router: CreateRecipeRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
        
    func onDismissPressed() {
        router.dismissScreen()
    }

    #if DEV || MOCK
    func onDevSettingsPressed() {
        router.showDevSettingsView()
    }
    #endif

    func onNextPressed() {
        guard let servingQuantity else {
            router.showSimpleAlert(
                title: String(localized: "Enter all required details"),
                subtitle: "Please specify the serving quantity of the dish"
            )
            return
        }
        let name = recipeName.capitalized
        
        let delegate = RecipePreparationDelegate(
            recipeName: name,
            servingQuantity: servingQuantity,
            recipeTotalWeight: recipeTotalWeight ?? 0.0,
            ingredients: ingredients
        )
        router.showRecipePreparationView(delegate: delegate)
    }
        
    func onAddIngredientPressed() {
        router.showIngredientListBuilderView(
            delegate: IngredientListBuilderDelegate(
                onRecipeIngredientConfirmed: { [weak self] (recipeIngredient: RecipeIngredientModel) in
                    guard let self else { return }
                    if let idx = self.ingredients.firstIndex(where: { $0.id == recipeIngredient.id }) {
                        self.ingredients[idx] = recipeIngredient
                    } else {
                        self.ingredients.append(recipeIngredient)
                    }
                },
                selectedFoods: ingredients.map { $0.ingredient }
            )
        )
    }
}
