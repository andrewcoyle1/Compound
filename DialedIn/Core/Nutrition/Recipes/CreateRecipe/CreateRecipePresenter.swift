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
    
    /// The total of the ingredients measured in grams, under the Ingredients header. Millilitres
    /// and units have no weight to add, so they are left out; with nothing weighed it is nil and
    /// the line is hidden. It used to read "0 g" whatever was in the list.
    var ingredientsWeightText: String? {
        let weighed = ingredients.filter { $0.unit == .grams }
        guard !weighed.isEmpty else { return nil }
        let total = weighed.reduce(0) { $0 + $1.amount }
        return String(localized: "Weight of ingredients is \(Format.grams(total))")
    }

    /// Both required fields are filled in. Next stays off until they are, rather than objecting
    /// afterwards; a missing name used to go through and save a recipe with no name.
    var canSave: Bool {
        !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (servingQuantity ?? 0) > 0
    }

    /// Anything entered that closing would throw away.
    var hasUnsavedChanges: Bool {
        !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || servingQuantity != nil
            || recipeTotalWeight != nil
            || !ingredients.isEmpty
    }

    init(
        interactor: CreateRecipeInteractor,
        router: CreateRecipeRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
        
    /// Closing asks first when there is something to lose.
    func onDismissPressed() {
        guard hasUnsavedChanges else {
            router.dismissScreen()
            return
        }
        router.showConfirmationDialog(
            title: String(localized: "Discard this recipe?"),
            subtitle: nil,
            buttons: {
                AnyView(
                    Group {
                        Button("Discard Recipe", role: .destructive) {
                            self.router.dismissScreen()
                        }
                        Button("Keep Editing", role: .cancel) { }
                    }
                )
            }
        )
    }

    func onDeleteIngredients(at offsets: IndexSet) {
        ingredients.remove(atOffsets: offsets)
    }

    func onNextPressed() {
        guard canSave, let servingQuantity else { return }
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
