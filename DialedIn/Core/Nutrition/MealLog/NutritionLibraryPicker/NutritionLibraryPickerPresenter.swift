//
//  NutritionLibraryPickerPresenter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 26/10/2025.
//

import SwiftUI

@Observable
@MainActor
class NutritionLibraryPickerPresenter {
    private let interactor: NutritionLibraryPickerInteractor
    private let router: NutritionLibraryPickerRouter

    private(set) var mode: NutritionPickerMode = .search
    
    init(
        interactor: NutritionLibraryPickerInteractor,
        router: NutritionLibraryPickerRouter
    ) {
        self.interactor = interactor
        self.router = router
    }
        
    func onModePressed(_ mode: NutritionPickerMode) {
        self.mode = mode
    }
    
    func navToIngredientAmount(_ ingredient: FoodModel, onPick: @escaping (MealItemModel) -> Void) {
        if ingredient.authorId == nil {
            Task { await interactor.saveExternalFood(ingredient) }
        }
        // Quick Add promises exactly this: the food's default portion, without the amount screen.
        // The picker stays open, so the next food is one tap away too.
        if interactor.foodLogSettings.quickAddEnabled {
            onPick(ingredient.mealItem(amount: ingredient.defaultPortionAmount))
            return
        }
        router.showIngredientAmountView(delegate: IngredientAmountDelegate(ingredient: ingredient, onPick: onPick))
    }

    func navToRecipeAmount(_ recipe: RecipeTemplateModel, onPick: @escaping (MealItemModel) -> Void) {
        router.showRecipeAmountView(delegate: RecipeAmountDelegate(recipe: recipe, onPick: onPick))
    }

    func dismissScreen() {
        router.dismissScreen()
    }
    
#if DEV || MOCK
func onDevSettingsPressed() {
    router.showDevSettingsView()
}
#endif
}

enum NutritionPickerMode: String, CaseIterable, DataSyncModelProtocol {
    
    var id: String { self.rawValue }
    
    case barcode
    case search
    case aiScanner
    case quickAdd
    case library
    case describe
    
    var title: String {
        switch self {
        case .barcode: return String(localized: "Barcode")
        case .search: return String(localized: "Search")
        case .aiScanner: return String(localized: "AI")
        case .quickAdd: return String(localized: "Quick Add")
        case .library: return String(localized: "Library")
        case .describe: return String(localized: "Describe")
        }
    }
    
    var systemName: String {
        switch self {
        case .barcode: return "barcode"
        case .search: return "magnifyingglass"
        case .aiScanner: return "wand.and.stars"
        case .quickAdd: return "hare"
        case .library: return "book"
        case .describe: return "pencil"
        }
    }
}
