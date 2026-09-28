import SwiftUI

@MainActor
protocol BarcodeScannerInteractor: GlobalInteractor, CameraAccessInteractor {
    var currentUser: UserModel? { get }
    func analyzeNutritionLabel(text: String) async throws -> String
    func saveFood(_ ingredient: FoodModel, image: PlatformImage?) async throws
    func lookupBarcode(_ code: String) async throws -> FoodModel
    func findLocalFood(withBarcode barcode: String) -> FoodModel?
}

extension CoreInteractor: BarcodeScannerInteractor {
    func lookupBarcode(_ code: String) async throws -> FoodModel {
        try await openFoodFactsService.lookupBarcode(code)
    }

    func findLocalFood(withBarcode barcode: String) -> FoodModel? {
        foodManager.foods.first { $0.barcode == barcode }
    }
}
