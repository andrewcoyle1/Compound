import SwiftUI

private struct FoodAnalysisResponse: Decodable {
    let items: [FoodAnalysisItem]
}

struct FoodAnalysisItem: Identifiable, Decodable {
    let id: String
    let name: String
    let amountGrams: Double
    let calories: Double?
    let proteinGrams: Double?
    let carbGrams: Double?
    let fatGrams: Double?
    let ingredientId: String?
}

@Observable
@MainActor
class FoodPhotoScannerPresenter {

    private let interactor: FoodPhotoScannerInteractor
    private let router: FoodPhotoScannerRouter

    private(set) var isAnalysing: Bool = false
    private(set) var analysisResults: [FoodAnalysisItem] = []
    private(set) var errorMessage: String?

    init(interactor: FoodPhotoScannerInteractor, router: FoodPhotoScannerRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onCapture(_ image: UIImage) async {
        guard interactor.ensureOnline(or: router) else { return }
        isAnalysing = true
        errorMessage = nil
        analysisResults = []
        interactor.trackEvent(event: Event.onCapture)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = String(localized: "Failed to process image.")
            isAnalysing = false
            return
        }

        do {
            let json = try await interactor.analyzeFood(imageData: data)
            let decoded = try JSONDecoder().decode(FoodAnalysisResponse.self, from: Data(json.utf8))
            analysisResults = decoded.items
        } catch {
            errorMessage = error.localizedDescription
            interactor.trackEvent(event: Event.onError(message: error.localizedDescription))
        }
        isAnalysing = false
    }

    func onRetakePressed() {
        isAnalysing = false
        analysisResults = []
        errorMessage = nil
    }

    func makeMealItem(from item: FoodAnalysisItem) -> MealItemModel {
        interactor.trackEvent(event: Event.onAddItem(name: item.name))
        var nutrients = NutrientMap()
        if let val = item.calories { nutrients[.calories] = val }
        if let val = item.proteinGrams { nutrients[.protein] = val }
        if let val = item.carbGrams { nutrients[.carbs] = val }
        if let val = item.fatGrams { nutrients[.fatTotal] = val }
        return MealItemModel(
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
    }
}

extension FoodPhotoScannerPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case onCapture
        case onAddItem(name: String)
        case onError(message: String)

        var eventName: String {
            switch self {
            case .onAppear:   return "FoodPhotoScannerView_Appear"
            case .onCapture:  return "FoodPhotoScanner_Capture"
            case .onAddItem:  return "FoodPhotoScanner_AddItem"
            case .onError:    return "FoodPhotoScanner_Error"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAddItem(let name):    return ["item_name": name]
            case .onError(let message):  return ["error": message]
            default:                     return nil
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
