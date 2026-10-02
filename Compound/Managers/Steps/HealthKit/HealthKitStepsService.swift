// 
//  HealthKitStepsService.swift
//  Compound
// 
//  Created by Andrew Coyle on 29/10/2025.
// 
#if canImport(HealthKit)
import HealthKit

struct HealthKitStepsSample: Equatable {
    let id: String
    let steps: Int
    let date: Date
}

enum HealthKitStepsServiceError: Error {
    case healthDataUnavailable
}

protocol HealthKitStepsService: Sendable {
    /// - Parameters:
    ///   - since: Last sync date; when nil, fetch from earliestDate or default range.
    ///   - earliestDate: Do not import steps before this date (e.g. user creation date).
    func readStepsSamples(since: Date?, earliestDate: Date?) async throws -> [HealthKitStepsSample]
    func saveStepsSample(steps: Int, date: Date) async throws -> String
}
#endif
