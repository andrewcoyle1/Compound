//
//  TodayInteractor.swift
//  DialedIn
//

import Foundation

@MainActor
protocol TodayInteractor: ReminderOfferInteractor {
    var userId: String? { get }
    var userImageUrl: String? { get }
    var currentUser: UserModel? { get }
    var activeTrainingProgram: TrainingProgram? { get }
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
}

extension CoreInteractor: TodayInteractor { }
