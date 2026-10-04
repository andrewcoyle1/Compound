import SwiftUI

@Observable
@MainActor
class IngredientListBuilderPresenter {
    
    private let interactor: IngredientListBuilderInteractor
    private let router: IngredientListBuilderRouter
    
    var isLoading: Bool = false
    var searchText: String = ""
    
    var userFoods: [FoodModel] {
        interactor.foods
            .filter { interactor.foodLogSettings.showBrandedFoods || $0.brandName == nil }
            .sortedByKeyPath(keyPath: \.name, ascending: true)
    }

    var systemFoods: [FoodModel] = []

    var filteredFoods: [FoodModel] {
        interactor.foods
            .filter { interactor.foodLogSettings.showBrandedFoods || $0.brandName == nil }
            .filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.description?.lowercased().contains(searchText.lowercased()) == true
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

    func onDismissPressed() {
        router.dismissScreen()
    }

    init(interactor: IngredientListBuilderInteractor, router: IngredientListBuilderRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
    
    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }
        
    func onAddIngredientPressed(delegate: IngredientListBuilderDelegate) {
        interactor.trackEvent(event: Event.onAddIngredientPressed)
        router.showCreateFoodView(delegate: CreateFoodDelegate(mealItems: delegate.mealItems))
    }

    /// Picking an ingredient is what this screen exists for, and neither route out of it was
    /// tracked — so the one action worth measuring here was never measured. Both routes log the
    /// same event and name the route in `method`, so the total stays one number.
    func navToIngredientAmountView(food: FoodModel, delegate: IngredientListBuilderDelegate) {
        interactor.trackEvent(event: Event.ingredientSelected(food: food, method: "amount"))
        if let recipeCallback = delegate.onRecipeIngredientConfirmed {
            router.showRecipeIngredientAmountView(delegate: RecipeIngredientAmountDelegate(
                food: food,
                onConfirm: recipeCallback
            ))
        } else if delegate.onMealItemConfirmed != nil {
            // The amount screen search and the barcode use, with Log beside Add to Plate. This
            // opened a different one, in grams rather than the food's portion and with no Log.
            router.showIngredientAmountView(delegate: IngredientAmountDelegate(
                ingredient: food,
                onPick: { item in delegate.onMealItemConfirmed?(item) },
                onLog: delegate.onLog
            ))
        } else {
            delegate.onIngredientSelectionChanged?(food)
        }
    }

    func quickAdd(food: FoodModel, delegate: IngredientListBuilderDelegate) {
        interactor.trackEvent(event: Event.ingredientSelected(food: food, method: "quickAdd"))
        if let recipeCallback = delegate.onRecipeIngredientConfirmed {
            let unit: IngredientAmountUnit = food.measurementMethod == .volume ? .milliliters : .grams
            let defaultAmount = food.portionGramsCalculated ?? food.portionMillilitersCalculated ?? 100
            recipeCallback(RecipeIngredientModel(ingredient: food, amount: defaultAmount, unit: unit))
        } else if delegate.onMealItemConfirmed != nil {
            // Built as search's "+" builds it, at the amount last logged; this used its own
            // version, at the default portion.
            let item = food.quickAddItem(lastLoggedIn: interactor.userMeals)
            interactor.playHaptic(option: .success)
            delegate.onMealItemConfirmed?(item)
        } else {
            delegate.onIngredientSelectionChanged?(food)
        }
    }

    // MARK: Analytics Events
    
    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case onAddIngredientPressed
        case ingredientSelected(food: FoodModel, method: String)

        var eventName: String {
            switch self {
            case .onAppear:                 return "IngredientsView_Appear"
            case .onDisappear:              return "IngredientsView_Disappear"
            case .onAddIngredientPressed:   return "IngredientsView_AddIngredientPressed"
            case .ingredientSelected:       return "IngredientsView_Ingredient_Selected"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            // Id and name rather than the model's full `eventParameters`: this fires on every tap,
            // and the rest of the record is recoverable from the id.
            case .ingredientSelected(food: let food, method: let method):
                return ["ingredient_id": food.id, "ingredient_name": food.name, "method": method]
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
