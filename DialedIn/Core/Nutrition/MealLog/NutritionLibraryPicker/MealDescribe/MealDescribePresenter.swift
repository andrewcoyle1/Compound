import SwiftUI

private struct FoodAnalysisResponse: Decodable {
    let items: [FoodAnalysisItem]
}

@Observable
@MainActor
class MealDescribePresenter {

    private let interactor: MealDescribeInteractor
    private let router: MealDescribeRouter

    var descriptionText: String = ""
    let characterLimit = 500

    private(set) var isAnalysing = false
    private(set) var analysisResults: [FoodAnalysisItem] = []
    private(set) var errorMessage: String?

    init(interactor: MealDescribeInteractor, router: MealDescribeRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: MealDescribeDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: MealDescribeDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onLogFoodsPressed() async {
        guard !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty,
              interactor.ensureOnline(or: router) else { return }
        isAnalysing = true
        errorMessage = nil
        analysisResults = []
        interactor.trackEvent(event: Event.onSubmit(text: descriptionText))
        do {
            let json = try await interactor.describeMeal(text: descriptionText)
            let decoded = try JSONDecoder().decode(FoodAnalysisResponse.self, from: Data(json.utf8))
            analysisResults = decoded.items
        } catch {
            errorMessage = error.localizedDescription
            interactor.trackEvent(event: Event.onError(message: error.localizedDescription))
        }
        isAnalysing = false
    }

    func onAddItem(_ item: FoodAnalysisItem, delegate: MealDescribeDelegate) {
        interactor.trackEvent(event: Event.onAddItem(name: item.name))
        var nutrients = NutrientMap()
        if let val = item.calories { nutrients[.calories] = val }
        if let val = item.proteinGrams { nutrients[.protein] = val }
        if let val = item.carbGrams { nutrients[.carbs] = val }
        if let val = item.fatGrams { nutrients[.fatTotal] = val }
        let mealItem = MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .ingredient,
            sourceId: item.ingredientId ?? UUID().uuidString,
            displayName: item.name,
            amount: item.amountGrams,
            unit: "g",
            resolvedGrams: item.amountGrams,
            resolvedMilliliters: nil,
            nutrients: nutrients
        )
        delegate.onPick(mealItem)
    }
}

extension MealDescribePresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: MealDescribeDelegate)
        case onDisappear(delegate: MealDescribeDelegate)
        case onSubmit(text: String)
        case onAddItem(name: String)
        case onError(message: String)

        var eventName: String {
            switch self {
            case .onAppear:    return "MealDescribeView_Appear"
            case .onDisappear: return "MealDescribeView_Disappear"
            case .onSubmit:    return "MealDescribe_Submit"
            case .onAddItem:   return "MealDescribe_AddItem"
            case .onError:     return "MealDescribe_Error"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onSubmit(let text):
                return ["text_length": text.count]
            case .onAddItem(let name):
                return ["item_name": name]
            case .onError(let message):
                return ["error": message]
            }
        }

        var type: LogType {
            switch self {
            case .onError: return .severe
            default:       return .analytic
            }
        }
    }
}
