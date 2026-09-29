//
//  RecipeDetailPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/10/2025.
//

import SwiftUI

@Observable
@MainActor
class RecipeDetailPresenter {
    private let interactor: RecipeDetailInteractor
    private let router: RecipeDetailRouter

    var isBookmarked: Bool = false
    var isFavourited: Bool = false

    var showStartSessionSheet: Bool = false
    
    #if DEBUG || MOCK
    var showDebugView: Bool = false
    #endif
    
    var currentUser: UserModel? {
        interactor.currentUser
    }
    init(
        interactor: RecipeDetailInteractor,
        router: RecipeDetailRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
        
    func onViewAppear(delegate: RecipeDetailDelegate) {
        isFavourited = interactor.isFavouriteRecipe(id: delegate.recipeTemplate.id)
    }

    /// Favourites live on the food log settings, which is what the library's Favourites tab reads.
    func onFavouritePressed(delegate: RecipeDetailDelegate) {
        let newValue = !isFavourited
        isFavourited = newValue
        Task {
            do {
                try await interactor.setFavouriteRecipe(id: delegate.recipeTemplate.id, isFavourite: newValue)
            } catch {
                isFavourited = !newValue
            }
        }
    }

    /// The servings the stepper is set to, or nil while it is still on the recipe as written.
    private(set) var servingsOverride: Double?

    /// Stepper bounds: half a serving at a time, so a halved recipe is one tap.
    static let servingsStep: Double = 0.5
    static let servingsRange: ClosedRange<Double> = 0.5...100

    func servings(recipe: RecipeTemplateModel) -> Double {
        servingsOverride ?? NutritionScaling.servingDivisor(recipe)
    }

    func onServingsChanged(_ servings: Double) {
        servingsOverride = servings.clamped(to: Self.servingsRange, whenNotFinite: Self.servingsRange.lowerBound)
    }

    /// An ingredient's amount for the servings chosen, to one decimal place.
    func scaledAmount(_ ingredient: RecipeIngredientModel, recipe: RecipeTemplateModel) -> Double {
        NutritionScaling.rounded(ingredient.amount * NutritionScaling.factor(servings: servings(recipe: recipe), of: recipe))
    }

    /// The whole of what the stepper makes — every serving, not one.
    func scaledNutrients(recipe: RecipeTemplateModel) -> NutrientMap {
        NutritionScaling.nutrients(of: recipe).scaled(by: NutritionScaling.factor(servings: servings(recipe: recipe), of: recipe))
    }

    func displayUnit(_ unit: IngredientAmountUnit) -> String {
        switch unit {
        case .grams: return "g"
        case .milliliters: return "ml"
        case .units: return "units"
        }
    }

#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif

    func onStartRecipePressed(recipe: RecipeTemplateModel) {
        router.showStartRecipeView(delegate: RecipeStartDelegate(recipe: recipe))
    }

    private(set) var isDeleting: Bool = false

    func canDelete(recipe: RecipeTemplateModel) -> Bool {
        recipe.authorId != nil && recipe.authorId == currentUser?.userId
    }

    func showDeleteConfirmation(recipe: RecipeTemplateModel) {
        router.showAlert(title: String(localized: "Delete Recipe"), subtitle: String(localized: "Are you sure you want to delete '\(recipe.name)'? This action cannot be undone."), buttons: {
            AnyView(
                HStack {
                    Button("Delete", role: .destructive) {
                        Task {
                            await self.deleteRecipe(recipe, onDismiss: { self.router.dismissScreen() })
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            )
        })
    }

    /// `onDismiss` is the router's dismiss in the app; a parameter so a test can see it happen.
    func deleteRecipe(_ recipe: RecipeTemplateModel, onDismiss: @escaping () -> Void) async {
        isDeleting = true
        do {
            try await interactor.deleteRecipeTemplate(id: recipe.id)
            onDismiss()
        } catch {
            isDeleting = false
            router.showSimpleAlert(title: String(localized: "Failed to delete recipe"), subtitle: String(localized: "Please try again later"))
        }
    }
}
