import SwiftUI

@MainActor
protocol NutritionAnalyticsRouter: GlobalRouter {
    func showNutritionMetricDetailView(metric: NutritionMetric, delegate: NutritionMetricDetailDelegate, themeColor: Color?)
    func showAddMealView(delegate: AddMealDelegate)
}

extension CoreRouter: NutritionAnalyticsRouter { }
