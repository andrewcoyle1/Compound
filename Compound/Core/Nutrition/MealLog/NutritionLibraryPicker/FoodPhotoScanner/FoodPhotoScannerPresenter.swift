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

    /// A transient food built from the estimate, scaled to per 100 g — what `IngredientAmountView`
    /// reads — so opening it at `amountGrams` shows the same figures the result row did.
    var estimatedFood: FoodModel {
        let density = amountGrams > 0 ? 100.0 / amountGrams : 1.0
        var nutrients = NutrientMap()
        if let calories { nutrients[.calories] = calories * density }
        if let proteinGrams { nutrients[.protein] = proteinGrams * density }
        if let carbGrams { nutrients[.carbs] = carbGrams * density }
        if let fatGrams { nutrients[.fatTotal] = fatGrams * density }
        return FoodModel(ingredientId: ingredientId ?? UUID().uuidString, name: name, nutrients: nutrients)
    }
}

@Observable
@MainActor
class FoodPhotoScannerPresenter {

    private let interactor: FoodPhotoScannerInteractor
    private let router: FoodPhotoScannerRouter

    private(set) var isAnalysing: Bool = false
    private(set) var analysisResults: [FoodAnalysisItem] = []
    private(set) var errorMessage: String?

    /// Whether the camera can be shown, and if not, why not.
    private(set) var cameraAccess: CameraAccess = .notDetermined

    init(interactor: FoodPhotoScannerInteractor, router: FoodPhotoScannerRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    /// Asks for the camera the first time the AI tab is opened. A refusal used to leave a capture
    /// button over a black preview, with nothing to say why.
    func onCameraNeeded(isSupported: Bool) async {
        cameraAccess = await interactor.resolveCameraAccess(isSupported: isSupported)
        if cameraAccess == .denied {
            interactor.trackEvent(event: Event.onCameraDenied)
        }
    }

    func onOpenSettingsPressed() {
        interactor.trackEvent(event: Event.onOpenSettings)
        interactor.openAppSettings()
    }

    func onCapture(_ image: UIImage) async {
        // The photo is already on screen, so say why no results follow rather than leave an empty
        // Results section under the offline alert.
        guard interactor.ensureOnline(or: router) else {
            errorMessage = String(localized: "You're offline. Connect to the internet to analyze this photo.")
            return
        }
        isAnalysing = true
        errorMessage = nil
        analysisResults = []
        didAddAll = false
        interactor.trackEvent(event: Event.onCapture)

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = String(localized: "Couldn't read this photo. Please retake it.")
            interactor.playHaptic(option: .error)
            isAnalysing = false
            return
        }

        do {
            let json = try await interactor.analyzeFood(imageData: data)
            let decoded = try JSONDecoder().decode(FoodAnalysisResponse.self, from: Data(json.utf8))
            analysisResults = decoded.items
        } catch {
            errorMessage = String(localized: "Couldn't recognize the food in this photo. Retake it in good light, or use Search or Describe.")
            interactor.playHaptic(option: .error)
            interactor.trackEvent(event: Event.onError(message: error.localizedDescription))
        }
        isAnalysing = false
    }

    func onRetakePressed() {
        isAnalysing = false
        analysisResults = []
        didAddAll = false
        errorMessage = nil
    }

    func makeMealItem(from item: FoodAnalysisItem) -> MealItemModel {
        interactor.trackEvent(event: Event.onAddItem(name: item.name))
        return item.mealItem
    }

    /// Set once Add All has put this shot's results on the plate, so a second tap cannot add them
    /// twice. A new shot clears it.
    private(set) var didAddAll = false

    /// Every result onto the plate at its estimate, in one tap. Correcting an amount is still a tap
    /// on its row away.
    func onAddAllPressed(onPick: (MealItemModel) -> Void) {
        guard !didAddAll, !analysisResults.isEmpty else { return }
        didAddAll = true
        interactor.trackEvent(event: Event.onAddAll(count: analysisResults.count))
        analysisResults.forEach { onPick($0.mealItem) }
        interactor.playHaptic(option: .success)
    }

    /// Estimates can be wrong, so a tapped result opens the amount screen prefilled rather than
    /// adding it as is — the amount and, through it, the macros can be corrected first.
    func onResultTapped(_ item: FoodAnalysisItem, onPick: @escaping (MealItemModel) -> Void, onLog: (() -> Void)? = nil) {
        interactor.trackEvent(event: Event.onAddItem(name: item.name))
        router.showIngredientAmountView(delegate: IngredientAmountDelegate(
            ingredient: item.estimatedFood,
            onPick: onPick,
            initialAmountText: item.amountGrams.formatted(.number.grouping(.never)),
            onLog: onLog
        ))
    }
}

extension FoodPhotoScannerPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case onCapture
        case onAddItem(name: String)
        case onAddAll(count: Int)
        case onError(message: String)
        case onCameraDenied
        case onOpenSettings

        var eventName: String {
            switch self {
            case .onAppear:   return "FoodPhotoScannerView_Appear"
            case .onCapture:  return "FoodPhotoScanner_Capture"
            case .onAddItem:  return "FoodPhotoScanner_AddItem"
            case .onAddAll:   return "FoodPhotoScanner_AddAll"
            case .onError:    return "FoodPhotoScanner_Error"
            case .onCameraDenied: return "FoodPhotoScanner_CameraDenied"
            case .onOpenSettings: return "FoodPhotoScanner_OpenSettings"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAddItem(let name):    return ["item_name": name]
            case .onAddAll(let count):    return ["item_count": count]
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

extension FoodAnalysisItem {
    /// The estimate as a meal item, as is. The model's figures are absolute for the amount it
    /// estimated, so they go through unscaled; a nutrient it did not give stays absent.
    var mealItem: MealItemModel {
        var nutrients = NutrientMap()
        if let calories { nutrients[.calories] = calories }
        if let proteinGrams { nutrients[.protein] = proteinGrams }
        if let carbGrams { nutrients[.carbs] = carbGrams }
        if let fatGrams { nutrients[.fatTotal] = fatGrams }
        return MealItemModel(
            itemId: UUID().uuidString,
            sourceType: .ingredient,
            sourceId: ingredientId ?? UUID().uuidString,
            displayName: name,
            amount: amountGrams,
            unit: "g",
            resolvedGrams: amountGrams,
            resolvedMilliliters: nil,
            nutrients: nutrients
        )
    }
}
