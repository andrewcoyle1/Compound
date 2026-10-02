import SwiftUI

@MainActor
protocol OptimisationInteractor: GlobalInteractor {
    var foodLogSettings: FoodLogSettings { get }
    func saveFoodLogSettings(_ settings: FoodLogSettings) async throws
}

extension CoreInteractor: OptimisationInteractor { }
