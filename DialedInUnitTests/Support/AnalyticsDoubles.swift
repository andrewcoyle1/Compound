//
//  AnalyticsDoubles.swift
//  DialedInUnitTests
//
//  Created by Andrew Coyle on 20/09/2026.
//

import Foundation
import SwiftUI
@testable import DialedIn

/// The Analytics tab's interactor and router doubles.
///
/// The tab is a summary of everything else in the app, so its interactor reaches into body
/// measurements, workouts, nutrition, steps, goals and the exercise library, and its router can open
/// two dozen screens. Both doubles live here so the test file stays about the derivations rather
/// than the wiring.
@MainActor
final class AnalyticsInteractorDouble: SpyGlobalInteractor, AnalyticsInteractor {
    var analyticsSettings: AnalyticsSettings = AnalyticsSettings(authorId: "author-1")
    var userImageUrl: String?
    var activeTests: ActiveABTests = ActiveABTests(paywallTest: .default)
    var userId: String? = "author-1"
    var currentUser: UserModel? = UserModel(userId: "author-1")
    var bodyMeasurements: [BodyMeasurementEntry] = []
    var currentGoal: WeightGoal?
    var auth: UserAuthInfo?
    var workoutSessions: [WorkoutSessionModel] = []
    var allExercises: [ExerciseModel] = []
    var systemExercises: [ExerciseModel] = []
    var userExercises: [ExerciseModel] = []
    var stepsHistory: [StepsModel] = []

    /// Calories and macros logged, by day key. A day absent is answered as zero, as the real
    /// `MealLogManager` does.
    var totalsByDay: [String: DailyMacroTarget] = [:]
    var target: DailyMacroTarget?
    var tdee: Double = 3000
    var preferences: [String: ExerciseUnitPreference] = [:]
    private(set) var didBackfillSteps = false

    func getPreference(templateId: String) -> ExerciseUnitPreference {
        preferences[templateId] ?? ExerciseUnitPreference(exerciseModelId: templateId)
    }

    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget {
        totalsByDay[dayKey] ?? DailyMacroTarget(calories: 0, proteinGrams: 0, carbGrams: 0, fatGrams: 0)
    }

    func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget? {
        target
    }

    func estimateTDEE(user: UserModel?) -> Double {
        tdee
    }

    func backfillStepsFromHealthKit() async {
        didBackfillSteps = true
    }
}

@MainActor
final class AnalyticsRouterDouble: AnalyticsRouter {
    let router: AnyRouter = TestRouting.anyRouter
    private(set) var shown: [String] = []

    // Deliberately not behind `#if DEV || MOCK` the way the protocol's requirement is. The app
    // target gets `DEV` from `-DDEV` in its Debug build settings; the unit test target does not, so
    // under the Development scheme the requirement existed and the stub did not, and the test
    // target stopped compiling. An extra method in a configuration that does not require it is
    // harmless; a missing one is not.
    func showDevSettingsView() { shown.append("devSettings") }
    func showPaywall() { shown.append("paywall") }
    func showProfileViewZoom(transitionId: String?, namespace: Namespace.ID) { shown.append("profile") }
    func showScaleWeightView(delegate: ScaleWeightDelegate, themeColor: Color?) { shown.append("scaleWeight") }
    func showWeighInConsistencyView(delegate: WeighInConsistencyDelegate, themeColor: Color?) { shown.append("weighInConsistency") }
    func showWeightTrendView(delegate: WeightTrendDelegate, themeColor: Color?) { shown.append("weightTrend") }
    func showGoalProgressView(delegate: GoalProgressDelegate, themeColor: Color?) { shown.append("goalProgress") }
    func showEnergyBalanceView(delegate: EnergyBalanceDelegate, themeColor: Color?) { shown.append("energyBalance") }
    func showWorkoutView(delegate: WorkoutDelegate, themeColor: Color?) { shown.append("workout") }
    func showWorkoutConsistencyView(delegate: WorkoutConsistencyDelegate, themeColor: Color?) { shown.append("workoutConsistency") }
    func showExpenditureDetailView(delegate: ExpenditureDetailDelegate, themeColor: Color?) { shown.append("expenditure") }
    func showStepsView(delegate: StepsDelegate, themeColor: Color?) { shown.append("steps") }
    func showVisualBodyFatView(delegate: VisualBodyFatDelegate, themeColor: Color?) { shown.append("visualBodyFat") }
    func showInsightsAndAnalyticsView(delegate: InsightsAndAnalyticsDelegate) { shown.append("insightsAndAnalytics") }
    func showNutritionAnalyticsView(delegate: NutritionAnalyticsDelegate) { shown.append("nutrition") }
    func showNutritionMetricDetailView(metric: NutritionMetric, delegate: NutritionMetricDetailDelegate, themeColor: Color?) {
        shown.append("nutritionMetric-\(metric)")
    }
    func showHabitsView(delegate: HabitsDelegate) { shown.append("habits") }
    func showBodyMetricsView(delegate: BodyMetricsDelegate) { shown.append("bodyMetrics") }
    func showMuscleGroupsView(delegate: MuscleGroupsDelegate) { shown.append("muscleGroups") }
    func showMuscleGroupDetailView(muscle: Muscles, delegate: MuscleGroupDetailDelegate, themeColor: Color?) {
        shown.append("muscleGroupDetail")
    }
    func showExerciseAnalyticsView(delegate: ExerciseAnalyticsDelegate) { shown.append("exercises") }
    func showExerciseDetailView(templateId: String, name: String, delegate: ExerciseDetailDelegate, themeColor: Color?) {
        shown.append("exerciseDetail")
    }
    func showCustomiseAnalyticsView(delegate: CustomiseAnalyticsDelegate) { shown.append("customiseAnalytics") }
    func showWeeklyReviewView() { shown.append("weeklyReview") }
}
