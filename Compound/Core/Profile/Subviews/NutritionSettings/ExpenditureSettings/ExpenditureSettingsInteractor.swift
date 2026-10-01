import SwiftUI

@MainActor
protocol ExpenditureSettingsInteractor: GlobalInteractor {
    var nutritionStrategySettings: NutritionStrategySettings { get }
    var currentExpenditure: ExpenditureEstimate { get }
    func saveNutritionStrategySettings(_ settings: NutritionStrategySettings) async throws
}

extension CoreInteractor: ExpenditureSettingsInteractor { }
