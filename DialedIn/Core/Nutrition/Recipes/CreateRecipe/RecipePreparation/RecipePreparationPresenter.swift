import SwiftUI

@Observable
@MainActor
class RecipePreparationPresenter {

    private let interactor: RecipePreparationInteractor
    private let router: RecipePreparationRouter

    var preparationSteps: [String] = [""]
    var prepTime: Double?
    var cookTime: Double?
    var sourceURL: String = ""
    var image: PlatformImage?

    init(interactor: RecipePreparationInteractor, router: RecipePreparationRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: RecipePreparationDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: RecipePreparationDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onAddStepPressed() {
        preparationSteps.append("")
    }

    func onRemoveStep(atOffsets: IndexSet) {
        preparationSteps.remove(atOffsets: atOffsets)
    }

    func onMoveStep(from: IndexSet, toOffset: Int) {
        preparationSteps.move(fromOffsets: from, toOffset: toOffset)
    }

    private func buildRecipe(delegate: RecipePreparationDelegate) -> RecipeTemplateModel? {
        guard let userId = interactor.currentUser?.userId else { return nil }
        let steps = preparationSteps.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return RecipeTemplateModel.newRecipeTemplate(
            name: delegate.recipeName,
            authorId: userId,
            ingredients: delegate.ingredients,
            servingQuantity: delegate.servingQuantity,
            totalWeight: delegate.recipeTotalWeight > 0 ? delegate.recipeTotalWeight : nil,
            preparationSteps: steps,
            prepTimeMins: prepTime,
            cookTimeMins: cookTime,
            sourceURL: sourceURL.isEmpty ? nil : sourceURL
        )
    }

    func onCreatePressed(delegate: RecipePreparationDelegate) {
        guard let recipe = buildRecipe(delegate: delegate) else { return }
        Task {
            do {
                interactor.trackEvent(event: Event.createRecipeStart)
                try await interactor.saveRecipeTemplate(recipe, image: image)
                interactor.trackEvent(event: Event.createRecipeSuccess)
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.createRecipeFail(error: error))
                router.showSimpleAlert(title: String(localized: "Failed to save recipe"), subtitle: error.localizedDescription)
            }
        }
    }

    func onCreateAndAddPressed(delegate: RecipePreparationDelegate, onConfirm: @escaping (MealItemModel) -> Void) {
        guard let recipe = buildRecipe(delegate: delegate) else { return }
        Task {
            do {
                interactor.trackEvent(event: Event.createRecipeStart)
                try await interactor.saveRecipeTemplate(recipe, image: image)
                interactor.trackEvent(event: Event.createRecipeSuccess)
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
                onConfirm(item)
                router.dismissScreen()
            } catch {
                interactor.trackEvent(event: Event.createRecipeFail(error: error))
                router.showSimpleAlert(title: String(localized: "Failed to save recipe"), subtitle: error.localizedDescription)
            }
        }
    }
}

extension RecipePreparationPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: RecipePreparationDelegate)
        case onDisappear(delegate: RecipePreparationDelegate)
        case createRecipeStart
        case createRecipeSuccess
        case createRecipeFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:             return "RecipePreparationView_Appear"
            case .onDisappear:          return "RecipePreparationView_Disappear"
            case .createRecipeStart:    return "RecipePreparationView_CreateRecipe_Start"
            case .createRecipeSuccess:  return "RecipePreparationView_CreateRecipe_Success"
            case .createRecipeFail:     return "RecipePreparationView_CreateRecipe_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .createRecipeFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .createRecipeFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
