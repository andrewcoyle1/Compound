//
//  NutritionLibraryPickerPresenter.swift
//  Compound
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

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onModePressed(_ mode: NutritionPickerMode) {
        guard mode != self.mode else { return }
        interactor.playHaptic(option: .selection)
        self.mode = mode
        interactor.trackEvent(event: Event.tabSelected(mode: mode))
    }
    
    /// A row tap: the amount screen, unless the Quick Add setting asks for the one-tap add here
    /// too. `onLog` is the plate's Log, so the amount screen can log the meal as it adds.
    func navToIngredientAmount(
        _ ingredient: FoodModel,
        onPick: @escaping (MealItemModel) -> Void,
        onLog: @escaping () -> Void
    ) {
        if interactor.foodLogSettings.quickAddEnabled {
            quickAdd(ingredient, onPick: onPick)
            return
        }
        if ingredient.authorId == nil {
            Task { await interactor.saveExternalFood(ingredient) }
        }
        router.showIngredientAmountView(delegate: IngredientAmountDelegate(ingredient: ingredient, onPick: onPick, onLog: onLog))
    }

    /// A row's "+": straight onto the plate at the amount last logged, without the amount screen.
    /// The picker stays open, so the next food is one tap away too.
    func quickAdd(_ ingredient: FoodModel, onPick: (MealItemModel) -> Void) {
        if ingredient.authorId == nil {
            Task { await interactor.saveExternalFood(ingredient) }
        }
        interactor.playHaptic(option: .success)
        onPick(ingredient.quickAddItem(lastLoggedIn: interactor.userMeals))
    }

    func navToRecipeAmount(
        _ recipe: RecipeTemplateModel,
        onPick: @escaping (MealItemModel) -> Void,
        onLog: (() -> Void)? = nil
    ) {
        router.showRecipeAmountView(delegate: RecipeAmountDelegate(recipe: recipe, onPick: onPick, onLog: onLog))
    }

    /// A recipe row's "+": the servings last logged, without the amount screen.
    func quickAdd(_ recipe: RecipeTemplateModel, onPick: (MealItemModel) -> Void) {
        interactor.playHaptic(option: .success)
        onPick(recipe.quickAddItem(lastLoggedIn: interactor.userMeals))
    }

    func dismissScreen() {
        router.dismissScreen()
    }
}

extension NutritionLibraryPickerPresenter {
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case tabSelected(mode: NutritionPickerMode)

        var eventName: String {
            switch self {
            case .onAppear:     return "NutritionLibraryPickerView_Appear"
            case .onDisappear:  return "NutritionLibraryPickerView_Disappear"
            case .tabSelected:  return "NutritionLibraryPickerView_Tab_Selected"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .tabSelected(mode: let mode):
                return ["tab": mode.rawValue]
            default:
                return nil
            }
        }

        var type: LogType {
            .analytic
        }
    }
}

enum NutritionPickerMode: String, CaseIterable, DataSyncModelProtocol {
    
    var id: String { self.rawValue }
    
#if !targetEnvironment(macCatalyst)
    case barcode
#endif
    case search
    case aiScanner
    case quickAdd
    case library
    case describe
    
    var title: String {
        switch self {
#if !targetEnvironment(macCatalyst)
        case .barcode: return String(localized: "Barcode")
#endif
        case .search: return String(localized: "Search")
        case .aiScanner: return String(localized: "AI")
        case .quickAdd: return String(localized: "Quick Add")
        case .library: return String(localized: "Library")
        case .describe: return String(localized: "Describe")
        }
    }
    
    var systemName: String {
        switch self {
#if !targetEnvironment(macCatalyst)
        case .barcode: return Symbol.barcode
#endif
        case .search: return Symbol.search
        case .aiScanner: return Symbol.camera
        case .quickAdd: return "hare"
        case .library: return Symbol.library
        case .describe: return "text.bubble"
        }
    }
}
