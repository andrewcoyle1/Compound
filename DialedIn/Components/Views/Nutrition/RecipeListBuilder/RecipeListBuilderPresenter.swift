import SwiftUI

@Observable
@MainActor
class RecipeListBuilderPresenter {
    
    private let interactor: RecipeListBuilderInteractor
    private let router: RecipeListBuilderRouter
    
    private(set) var isLoading: Bool = false
    var searchText: String = ""
    
    var userRecipeTemplates: [RecipeTemplateModel] {
        interactor.userRecipeTemplates
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }
    
    var systemRecipeTemplates: [RecipeTemplateModel] = []
    
    var filteredRecipeTemplates: [RecipeTemplateModel] {
        interactor.userRecipeTemplates
            .filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.description?.lowercased().contains(searchText.lowercased()) == true ||
                $0.ingredients
                    .contains { value in
                        value.name.lowercased().contains(searchText.lowercased())
                    } == true
            }
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }
    
    var currentUser: UserModel? {
        interactor.currentUser
    }

    var showFoodImageInLogger: Bool { interactor.foodLogSettings.showFoodImageInLogger }
    var showCaloriesInLogger: Bool { interactor.foodLogSettings.showCaloriesInLogger }
    var showMacrosInLogger: Bool { interactor.foodLogSettings.showMacrosInLogger }
    var showPortionInLogger: Bool { interactor.foodLogSettings.showPortionInLogger }

    init(interactor: RecipeListBuilderInteractor, router: RecipeListBuilderRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
    
    func onAddRecipePressed() {
        router.showCreateRecipeView()
    }

    func onRecipePressed(recipe: RecipeTemplateModel, onRecipePressed: ((RecipeTemplateModel) -> Void)? = nil) {
        onRecipePressed?(recipe)
    }

    func navToRecipeAmountView(recipe: RecipeTemplateModel, delegate: RecipeListBuilderDelegate) {
        router.showRecipeAmountView(delegate: RecipeAmountDelegate(
            recipe: recipe,
            onPick: { delegate.onMealItemConfirmed?($0) }
        ))
    }

    func quickAdd(recipe: RecipeTemplateModel, delegate: RecipeListBuilderDelegate) {
        var nutrients = NutrientMap()
        for recipeIngredient in recipe.ingredients {
            let grams: Double
            switch recipeIngredient.unit {
            case .grams: grams = recipeIngredient.amount
            case .milliliters: grams = recipeIngredient.amount
            case .units: grams = recipeIngredient.amount * 100
            }
            for (key, value) in recipeIngredient.ingredient.nutrients {
                nutrients[key, default: 0] += value * (grams / 100.0)
            }
        }
        let perServing = nutrients.mapValues { $0 / max(recipe.servingQuantity, 1) }
        let item = MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .recipe,
            sourceId: recipe.recipeId,
            displayName: recipe.name,
            amount: 1,
            unit: "serving",
            resolvedGrams: nil,
            resolvedMilliliters: nil,
            nutrients: perServing
        )
        delegate.onMealItemConfirmed?(item)
    }

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear

        var eventName: String {
            switch self {
            case .onAppear:     return "RecipeListBuilderView_Appear"
            case .onDisappear:  return "RecipeListBuilderView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }

}
