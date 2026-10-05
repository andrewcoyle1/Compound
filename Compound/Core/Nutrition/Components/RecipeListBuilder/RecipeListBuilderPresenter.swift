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
            onPick: { delegate.onMealItemConfirmed?($0) },
            onLog: delegate.onLog
        ))
    }

    /// The row's "+": the servings last logged, built the way the amount screen builds it. This
    /// used to sum the nutrients itself, counting a "unit" ingredient as 100 g, so the same recipe
    /// logged different figures from here than from the amount screen.
    func quickAdd(recipe: RecipeTemplateModel, delegate: RecipeListBuilderDelegate) {
        interactor.playHaptic(option: .success)
        delegate.onMealItemConfirmed?(recipe.quickAddItem(lastLoggedIn: interactor.userMeals))
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
