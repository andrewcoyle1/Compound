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
        case onCameraDenied
        case onOpenSettings

        var eventName: String {
            switch self {
            case .onAppear:   return "FoodPhotoScannerView_Appear"
            case .onCapture:  return "FoodPhotoScanner_Capture"
            case .onAddItem:  return "FoodPhotoScanner_AddItem"
            case .onError:    return "FoodPhotoScanner_Error"
            case .onCameraDenied: return "FoodPhotoScanner_CameraDenied"
            case .onOpenSettings: return "FoodPhotoScanner_OpenSettings"
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
