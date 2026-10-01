import SwiftUI

@MainActor
protocol FoodPhotoScannerInteractor: GlobalInteractor, CameraAccessInteractor {
    func analyzeFood(imageData: Data) async throws -> String
}

extension CoreInteractor: FoodPhotoScannerInteractor { }
