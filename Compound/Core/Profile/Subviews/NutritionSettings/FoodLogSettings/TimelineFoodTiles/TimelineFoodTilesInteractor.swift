import SwiftUI

@MainActor
protocol TimelineFoodTilesInteractor: GlobalInteractor {
    var foodLogSettings: FoodLogSettings { get }
    func saveFoodLogSettings(_ settings: FoodLogSettings) async throws
}

extension CoreInteractor: TimelineFoodTilesInteractor { }
