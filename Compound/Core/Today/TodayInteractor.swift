//
//  TodayInteractor.swift
//  Compound
//

import Foundation

@MainActor
protocol TodayInteractor: ReminderOfferInteractor {
    var userId: String? { get }
    var userImageUrl: String? { get }
    var currentUser: UserModel? { get }
    var activeMesocycle: Mesocycle? { get }
    var activeMesocycleRun: MesocycleSchedule.Run? { get }
    var currentMacrocycle: Macrocycle? { get }
    func repeatCurrentMacrocycle() async throws
    var workoutSessions: [WorkoutSessionModel] { get }
    var activeSession: WorkoutSessionModel? { get }
    var draftMeal: MealLogModel? { get }
    var bodyMeasurements: [BodyMeasurementEntry] { get }
    var checkInState: CheckInState { get }
    func startBlankWorkout() async throws
    func deleteActiveSession() throws
    func deleteDraftMeal() throws
    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget
    func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget?
    func markCheckInSkipped(weekStart: Date) async throws

    // MARK: - Checklist
    var userMeals: [MealLogModel] { get }
    var currentGoal: WeightGoal? { get }
    var stepsHistory: [StepsModel] { get }
    func syncStepsFromHealthKit(fromScratch: Bool) async
    func canRequestHealthDataAuthorisation() -> Bool
    func requestHealthKitAuthorisation(for scope: HealthDataScope) async throws
    var analyticsSettings: AnalyticsSettings { get }
    func saveAnalyticsSettings(_ settings: AnalyticsSettings) async throws

    // MARK: - Getting started and friends
    var stravaIsConnected: Bool { get }
    var followingWorkoutSessions: [WorkoutSessionModel] { get }
    var followingUsers: [UserModel] { get }
}

extension CoreInteractor: TodayInteractor { }
