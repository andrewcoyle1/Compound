// 
//  HealthKitStepsService.swift
//  Compound
// 
//  Created by Andrew Coyle on 29/10/2025.
// 
#if canImport(HealthKit)
import HealthKit

enum HealthKitStepsServiceError: Error {
    case healthDataUnavailable
}

/// Every read leaves out samples this app wrote.
@MainActor
protocol HealthKitStepsService: Sendable {
    /// Changes to step samples starting on or after `start`.
    func changes(after anchor: Data?, since start: Date) async throws -> HealthKitDayChanges
    /// Each day's total from `start` up to `end`, keyed by the start of the day. Days with no
    /// steps are left out. Totals come from HealthKit's statistics, which count a step recorded
    /// by both iPhone and Watch once.
    func dailySteps(from start: Date, to end: Date) async throws -> [Date: Int]
    /// Fires when steps may have changed in Apple Health. Ends when cancelled.
    func changeNotifications() -> AsyncStream<Void>
}
#endif
