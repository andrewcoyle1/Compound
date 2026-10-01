import SwiftUI

@MainActor
protocol StrategySettingsInteractor: GlobalInteractor {
    var nutritionStrategySettings: NutritionStrategySettings { get }
    func saveNutritionStrategySettings(_ settings: NutritionStrategySettings) async throws
}

extension CoreInteractor: StrategySettingsInteractor { }
