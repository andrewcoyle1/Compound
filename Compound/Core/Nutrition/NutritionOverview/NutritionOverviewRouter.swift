import SwiftUI

@MainActor
protocol NutritionOverviewRouter: GlobalRouter {
    func showCheckInView(delegate: CheckInDelegate)
}

extension CoreRouter: NutritionOverviewRouter { }
