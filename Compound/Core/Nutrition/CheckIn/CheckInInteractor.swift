//
//  CheckInInteractor.swift
//  Compound
//

import SwiftUI

@MainActor
protocol CheckInInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var nutritionStrategySettings: NutritionStrategySettings { get }
    var bodyMeasurements: [BodyMeasurementEntry] { get }
    var currentExpenditure: ExpenditureEstimate { get }
    var targetProposal: TargetProposal? { get }
    var adherenceNote: AdherenceNote? { get }
    var loggingBreak: LoggingBreak? { get }
    var openLoggingBreak: LoggingBreak? { get }

    func getMeals(for dayKey: String) throws -> [MealLogModel]
    func nutritionDayAnnotation(dayKey: String) -> NutritionDayAnnotation?
    func saveNutritionDayAnnotations(_ annotations: [NutritionDayAnnotation]) async throws
    func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws
    func updateWeight(userId: String, weight: Double, weightUnitPreference: WeightUnitPreference) async throws
    func startLoggingBreak() async throws
    func endLoggingBreak() async throws
    func acceptTargetProposal() async throws
    func markCheckInCompleted(weekStart: Date) async throws
}

extension CoreInteractor: CheckInInteractor { }
