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
    /// Set once a description has been analysed successfully, so an empty result reads as "no
    /// foods recognized" rather than the screen showing nothing at all.
    private(set) var didAnalyse = false

    init(interactor: MealDescribeInteractor, router: MealDescribeRouter) {
        self.interactor = interactor
        self.router = router
    }

    var canAnalyse: Bool {
        !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty && !isAnalysing
    }

    /// Holds the description to `characterLimit`.
    func onDescriptionChanged(_ newValue: String) {
        if newValue.count > characterLimit {
            descriptionText = String(newValue.prefix(characterLimit))
        }
    }

    func onAnalysePressed() async {
        guard !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty,
              interactor.ensureOnline(or: router) else { return }
        isAnalysing = true
        errorMessage = nil
        analysisResults = []
        didAddAll = false
        interactor.trackEvent(event: Event.onSubmit(text: descriptionText))
        do {
            let json = try await interactor.describeMeal(text: descriptionText)
            let decoded = try JSONDecoder().decode(FoodAnalysisResponse.self, from: Data(json.utf8))
            analysisResults = decoded.items
            didAnalyse = true
            interactor.trackEvent(event: Event.analyseSuccess(count: decoded.items.count))
        } catch {
            errorMessage = String(localized: "Couldn't work out the foods in that description. Try naming each food and its amount, then try again.")
            interactor.playHaptic(option: .error)
            interactor.trackEvent(event: Event.onError(message: error.localizedDescription))
        }
        isAnalysing = false
    }

    /// Set once Add All has put these results on the plate, so a second tap cannot add them twice.
    /// A new analysis clears it.
    private(set) var didAddAll = false

    /// Every result onto the plate at its estimate, in one tap. Correcting an amount is still a tap
    /// on its row away.
    func onAddAllPressed(delegate: MealDescribeDelegate) {
        guard !didAddAll, !analysisResults.isEmpty else { return }
        didAddAll = true
        interactor.trackEvent(event: Event.onAddAll(count: analysisResults.count))
        analysisResults.forEach { delegate.onPick($0.mealItem) }
        interactor.playHaptic(option: .success)
    }

    /// Estimates can be wrong, so a tapped result opens the amount screen prefilled rather than
    /// adding it as is — the amount and, through it, the macros can be corrected first.
    func onResultTapped(_ item: FoodAnalysisItem, delegate: MealDescribeDelegate) {
        interactor.trackEvent(event: Event.onAddItem(name: item.name))
        router.showIngredientAmountView(delegate: IngredientAmountDelegate(
            ingredient: item.estimatedFood,
            onPick: delegate.onPick,
            initialAmountText: item.amountGrams.formatted(.number.grouping(.never)),
            onLog: delegate.onLog
        ))
    }
}

extension MealDescribePresenter {

    enum Event: LoggableEvent {
        case onSubmit(text: String)
        case analyseSuccess(count: Int)
        case onAddItem(name: String)
        case onAddAll(count: Int)
        case onError(message: String)

        var eventName: String {
            switch self {
            case .onSubmit:    return "MealDescribe_Submit"
            case .analyseSuccess: return "MealDescribeView_Analyse_Success"
            case .onAddItem:   return "MealDescribe_AddItem"
            case .onAddAll:    return "MealDescribe_AddAll"
            case .onError:     return "MealDescribe_Error"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onSubmit(let text):
                return ["text_length": text.count]
            case .onAddItem(let name):
                return ["item_name": name]
            case .onAddAll(let count), .analyseSuccess(let count):
                return ["item_count": count]
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
