import SwiftUI

@MainActor
protocol TimeSelectionInteractor: GlobalInteractor {
    var foodLogSettings: FoodLogSettings { get }
    func saveFoodLogSettings(_ settings: FoodLogSettings) async throws
}

extension CoreInteractor: TimeSelectionInteractor { }
