//
//  RecipeDetailPresenter.swift
//  Compound
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
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    /// Favourites live on the food log settings, which is what the library's Favourites tab reads.
    func onFavouritePressed(delegate: RecipeDetailDelegate) {
        let newValue = !isFavourited
        isFavourited = newValue
        interactor.trackEvent(event: Event.favouriteStart)
        Task {
            do {
                try await interactor.setFavouriteRecipe(id: delegate.recipeTemplate.id, isFavourite: newValue)
                interactor.trackEvent(event: Event.favouriteSuccess)
            } catch {
                isFavourited = !newValue
                interactor.trackEvent(event: Event.favouriteFail(error: error))
                router.showFailure(String(localized: "Unable to Update Favorites"), error: error)
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
        interactor.playHaptic(option: .selection)
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
        interactor.trackEvent(event: Event.deleteStart)
        do {
            try await interactor.deleteRecipeTemplate(id: recipe.id)
            interactor.trackEvent(event: Event.deleteSuccess)
            interactor.playHaptic(option: .success)
            onDismiss()
        } catch {
            isDeleting = false
            interactor.trackEvent(event: Event.deleteFail(error: error))
            interactor.playHaptic(option: .error)
            router.showSimpleAlert(title: String(localized: "Failed to delete recipe"), subtitle: String(localized: "Please try again later"))
        }
    }
}

extension RecipeDetailPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case favouriteStart
        case favouriteSuccess
        case favouriteFail(error: Error)
        case deleteStart
        case deleteSuccess
        case deleteFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:          return "RecipeDetailView_Appear"
            case .onDisappear:       return "RecipeDetailView_Disappear"
            case .favouriteStart:    return "RecipeDetailView_Favourite_Start"
            case .favouriteSuccess:  return "RecipeDetailView_Favourite_Success"
            case .favouriteFail:     return "RecipeDetailView_Favourite_Fail"
            case .deleteStart:       return "RecipeDetailView_Delete_Start"
            case .deleteSuccess:     return "RecipeDetailView_Delete_Success"
            case .deleteFail:        return "RecipeDetailView_Delete_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .favouriteFail(error: let error), .deleteFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .favouriteFail, .deleteFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
