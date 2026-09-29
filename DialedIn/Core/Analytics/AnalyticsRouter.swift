//
//  AnalyticsRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol AnalyticsRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showPaywall()
    func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID)
    func showScaleWeightView(delegate: ScaleWeightDelegate, themeColor: Color?)
    func showWeighInConsistencyView(delegate: WeighInConsistencyDelegate, themeColor: Color?)
    func showWeightTrendView(delegate: WeightTrendDelegate, themeColor: Color?)
    func showGoalProgressView(delegate: GoalProgressDelegate, themeColor: Color?)
    func showEnergyBalanceView(delegate: EnergyBalanceDelegate, themeColor: Color?)
    func showWorkoutView(delegate: WorkoutDelegate, themeColor: Color?)
    func showWorkoutConsistencyView(delegate: WorkoutConsistencyDelegate, themeColor: Color?)
    func showExpenditureDetailView(delegate: ExpenditureDetailDelegate, themeColor: Color?)
    func showStepsView(delegate: StepsDelegate, themeColor: Color?)
    func showVisualBodyFatView(delegate: VisualBodyFatDelegate, themeColor: Color?)
    func showInsightsAndAnalyticsView(delegate: InsightsAndAnalyticsDelegate)
    func showNutritionAnalyticsView(delegate: NutritionAnalyticsDelegate)
    func showNutritionMetricDetailView(metric: NutritionMetric, delegate: NutritionMetricDetailDelegate, themeColor: Color?)
    func showHabitsView(delegate: HabitsDelegate)
    func showBodyMetricsView(delegate: BodyMetricsDelegate)
    func showMuscleGroupsView(delegate: MuscleGroupsDelegate)
    func showMuscleGroupDetailView(muscle: Muscles, delegate: MuscleGroupDetailDelegate, themeColor: Color?)
    func showExerciseAnalyticsView(delegate: ExerciseAnalyticsDelegate)
    func showExerciseDetailView(templateId: String, name: String, delegate: ExerciseDetailDelegate, themeColor: Color?)
    func showCustomiseAnalyticsView(delegate: CustomiseAnalyticsDelegate)
    func showWeeklyReviewView()
}

extension CoreRouter: AnalyticsRouter { }
