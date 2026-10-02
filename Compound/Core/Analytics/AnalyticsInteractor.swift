//
//  AnalyticsInteractor.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

import Foundation

@MainActor
protocol AnalyticsInteractor: GlobalInteractor {
    /// Which sections the tab shows — see `CustomiseAnalyticsView`.
    var analyticsSettings: AnalyticsSettings { get }
    var userImageUrl: String? { get }
    var activeTests: ActiveABTests { get }
    var userId: String? { get }
    var currentUser: UserModel? { get }
    var bodyMeasurements: [BodyMeasurementEntry] { get }
    var currentGoal: WeightGoal? { get }
    var auth: UserAuthInfo? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var allExercises: [ExerciseModel] { get }
    var systemExercises: [ExerciseModel] { get }
    var userExercises: [ExerciseModel] { get }
    func getPreference(templateId: String) -> ExerciseUnitPreference
    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget
    func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget?
    func estimateTDEE(user: UserModel?) -> Double
    var stepsHistory: [StepsModel] { get }
    func backfillStepsFromHealthKit() async
    var expenditureHistory: [ExpenditureEstimate] { get }
}

extension CoreInteractor: AnalyticsInteractor { }
