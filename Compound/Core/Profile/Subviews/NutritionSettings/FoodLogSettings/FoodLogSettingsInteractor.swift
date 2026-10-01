import SwiftUI

@MainActor
protocol FoodLogSettingsInteractor: GlobalInteractor {
    var foodLogSettings: FoodLogSettings { get }
    func saveFoodLogSettings(_ settings: FoodLogSettings) async throws
}

extension CoreInteractor: FoodLogSettingsInteractor { }
