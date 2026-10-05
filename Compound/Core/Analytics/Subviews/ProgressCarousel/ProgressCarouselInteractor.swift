//
//  ProgressCarouselInteractor.swift
//  Compound
//

import Foundation

@MainActor
protocol ProgressCarouselInteractor: GlobalInteractor {
    var userId: String? { get }
    var currentUser: UserModel? { get }
    var workoutSessions: [WorkoutSessionModel] { get }
    var allExercises: [ExerciseModel] { get }
    var activeMesocycle: Mesocycle? { get }
    var expenditureHistory: [ExpenditureEstimate] { get }
    func estimateTDEE(user: UserModel?) -> Double
    func getPreference(templateId: String) -> ExerciseUnitPreference
    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget
    func getDailyTarget(for date: Date, userId: String) async throws -> DailyMacroTarget?
}

extension CoreInteractor: ProgressCarouselInteractor { }
