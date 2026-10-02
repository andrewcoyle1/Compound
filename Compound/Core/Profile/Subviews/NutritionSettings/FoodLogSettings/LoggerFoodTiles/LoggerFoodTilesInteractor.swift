import SwiftUI

@MainActor
protocol LoggerFoodTilesInteractor: GlobalInteractor {
    var foodLogSettings: FoodLogSettings { get }
    func saveFoodLogSettings(_ settings: FoodLogSettings) async throws
}

extension CoreInteractor: LoggerFoodTilesInteractor { }
