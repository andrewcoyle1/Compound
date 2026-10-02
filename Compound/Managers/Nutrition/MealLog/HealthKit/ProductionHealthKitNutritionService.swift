//
//  ProductionHealthKitNutritionService.swift
//  Compound
//
//  Created by Andrew Coyle on 02/10/2026.
//
#if canImport(HealthKit)
import HealthKit

struct ProductionHealthKitNutritionService: HealthKitNutritionService {

    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    /// Each imported type, with the nutrient it fills. Energy is stored in kcal, the rest in grams.
    private nonisolated static let nutrients: [(type: HKQuantityType, key: NutrientKey)] = [
        (HKQuantityType(.dietaryEnergyConsumed), .calories),
        (HKQuantityType(.dietaryProtein), .protein),
        (HKQuantityType(.dietaryCarbohydrates), .carbs),
        (HKQuantityType(.dietaryFatTotal), .fatTotal)
    ]

    nonisolated static var types: [HKQuantityType] { nutrients.map(\.type) }

    /// Read in pages and keep only the day of each, off the main actor, as the steps import does.
    @concurrent
    nonisolated func changes(after anchor: Data?, since start: Date) async throws -> HealthKitDayChanges {
        try checkAvailable()
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: nil),
            HKHealthStore.notFromThisApp
        ])
        let calendar = Calendar.current
        let pageSize = 10_000
        var changes = HealthKitDayChanges(changedDays: [], hasDeletions: false, anchor: anchor)
        var queryAnchor = HKHealthStore.anchor(from: anchor)
        while true {
            let descriptor = HKAnchoredObjectQueryDescriptor(
                predicates: Self.nutrients.map { .quantitySample(type: $0.type, predicate: predicate) },
                anchor: queryAnchor,
                limit: pageSize
            )
            let page = try await descriptor.result(for: healthStore)
            changes.changedDays.formUnion(page.addedSamples.map { calendar.startOfDay(for: $0.startDate) })
            changes.hasDeletions = changes.hasDeletions || !page.deletedObjects.isEmpty
            changes.anchor = HKHealthStore.data(from: page.newAnchor)
            queryAnchor = page.newAnchor
            if page.addedSamples.count + page.deletedObjects.count < pageSize { return changes }
        }
    }

    @concurrent
    nonisolated func dailyTotals(from start: Date, to end: Date) async throws -> [Date: NutrientMap] {
        try checkAvailable()
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: end),
            HKHealthStore.notFromThisApp
        ])
        var totals: [Date: NutrientMap] = [:]
        for nutrient in Self.nutrients {
            let descriptor = HKStatisticsCollectionQueryDescriptor(
                predicate: .quantitySample(type: nutrient.type, predicate: predicate),
                options: .cumulativeSum,
                anchorDate: Calendar.current.startOfDay(for: start),
                intervalComponents: DateComponents(day: 1)
            )
            try await descriptor.result(for: healthStore).enumerateStatistics(from: start, to: end) { statistics, _ in
                if let sum = statistics.sumQuantity() {
                    totals[statistics.startDate, default: NutrientMap()][nutrient.key] = sum.doubleValue(for: nutrient.key == .calories ? .kilocalorie() : .gram())
                }
            }
        }
        return totals
    }

    func changeNotifications() -> AsyncStream<Void> {
        healthStore.changeNotifications(for: Self.types)
    }

    private nonisolated func checkAvailable() throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitNutritionServiceError.healthDataUnavailable
        }
    }
}
#endif
