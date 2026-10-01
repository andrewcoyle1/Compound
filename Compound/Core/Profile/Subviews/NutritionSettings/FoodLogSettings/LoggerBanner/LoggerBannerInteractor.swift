import SwiftUI

@MainActor
protocol LoggerBannerInteractor: GlobalInteractor {
    var foodLogSettings: FoodLogSettings { get }
    func saveFoodLogSettings(_ settings: FoodLogSettings) async throws
}

extension CoreInteractor: LoggerBannerInteractor { }
