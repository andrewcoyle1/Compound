//
//  HealthKitNutritionService.swift
//  Compound
//
//  Created by Andrew Coyle on 02/10/2026.
//
#if canImport(HealthKit)
import HealthKit

enum HealthKitNutritionServiceError: Error {
    case healthDataUnavailable
}

/// Food logged in other apps, read from Apple Health as daily totals of energy and the three
/// macros. Every read leaves out samples this app wrote.
@MainActor
protocol HealthKitNutritionService: Sendable {
    /// Changes to dietary samples starting on or after `start`.
    func changes(after anchor: Data?, since start: Date) async throws -> HealthKitDayChanges
    /// Each day's totals from `start` up to `end`, keyed by the start of the day, holding only
    /// `.calories`, `.protein`, `.carbs` and `.fatTotal`. Days with nothing recorded are left out.
    func dailyTotals(from start: Date, to end: Date) async throws -> [Date: NutrientMap]
    /// Fires when dietary data may have changed in Apple Health. Ends when cancelled.
    func changeNotifications() -> AsyncStream<Void>
}
#endif
