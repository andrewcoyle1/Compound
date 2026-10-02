import SwiftUI

@MainActor
protocol FavouriteMeasurementsInteractor: GlobalInteractor {
    var foodLogSettings: FoodLogSettings { get }
    func saveFoodLogSettings(_ settings: FoodLogSettings) async throws
}

extension CoreInteractor: FavouriteMeasurementsInteractor { }
