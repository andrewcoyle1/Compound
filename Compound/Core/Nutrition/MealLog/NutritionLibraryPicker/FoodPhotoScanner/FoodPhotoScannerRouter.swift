import SwiftUI

@MainActor
protocol FoodPhotoScannerRouter: GlobalRouter {
    func showIngredientAmountView(delegate: IngredientAmountDelegate)
}

extension CoreRouter: FoodPhotoScannerRouter { }
