//
//  ProductionHealthKitStepsService.swift
//  Compound
//
//  Created by Andrew Coyle on 29/10/2025.
//
#if canImport(HealthKit)
import HealthKit

struct ProductionHealthKitStepsService: HealthKitStepsService {
    
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    func readStepsSamples(since: Date?, earliestDate: Date?) async throws -> [HealthKitStepsSample] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitStepsServiceError.healthDataUnavailable
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return []
        }

        let calendar = Calendar.current
        let endDate = Date()
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        let candidateStart = since ?? earliestDate ?? oneYearAgo
        let startDate = max(
            earliestDate ?? .distantPast,
            calendar.startOfDay(for: candidateStart)
        )

        let anchorDate = calendar.startOfDay(for: startDate)
        let interval = DateComponents(day: 1)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var samples: [HealthKitStepsSample] = []
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]

                results?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let steps = Int(statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    let date = statistics.startDate
                    let id = "healthkit-daily-\(formatter.string(from: date))"
                    samples.append(HealthKitStepsSample(id: id, steps: steps, date: date))
                }
                continuation.resume(returning: samples.sorted { $0.date < $1.date })
            }

            healthStore.execute(query)
        }
    }

    func saveStepsSample(steps: Int, date: Date) async throws -> String {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitStepsServiceError.healthDataUnavailable
        }

        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitStepsServiceError.healthDataUnavailable
        }
        let unit = HKUnit.count()
        let quantity = HKQuantity(unit: unit, doubleValue: Double(steps))
        let sample = HKQuantitySample(type: quantityType, quantity: quantity, start: date, end: date)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: URLError(.unknown))
                }
            }
        }

        return sample.uuid.uuidString
    }
}
#endif
