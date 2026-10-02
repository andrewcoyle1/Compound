import SwiftUI

@MainActor
protocol HabitsRouter: GlobalRouter {
    func showScaleWeightView(delegate: ScaleWeightDelegate, themeColor: Color?)
    func showWeighInConsistencyView(delegate: WeighInConsistencyDelegate, themeColor: Color?)
    func showWorkoutView(delegate: WorkoutDelegate, themeColor: Color?)
    func showWorkoutConsistencyView(delegate: WorkoutConsistencyDelegate, themeColor: Color?)
    func showFoodLoggingConsistencyView(delegate: FoodLoggingConsistencyDelegate, themeColor: Color?)
    func showNutritionMetricDetailView(metric: NutritionMetric, delegate: NutritionMetricDetailDelegate, themeColor: Color?)
}

extension CoreRouter: HabitsRouter { }
