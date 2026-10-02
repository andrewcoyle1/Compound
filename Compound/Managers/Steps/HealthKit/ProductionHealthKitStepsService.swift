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

    private nonisolated static let stepCount = HKQuantityType(.stepCount)

    /// A Watch records steps every few minutes, so a first read with no anchor can return
    /// hundreds of thousands of samples. Read in pages and keep only the day of each, off the main
    /// actor: the protocol is main-actor isolated, and this struct would otherwise inherit it.
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
                predicates: [.quantitySample(type: Self.stepCount, predicate: predicate)],
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
    nonisolated func dailySteps(from start: Date, to end: Date) async throws -> [Date: Int] {
        try checkAvailable()
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(
                type: Self.stepCount,
                predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                    HKQuery.predicateForSamples(withStart: start, end: end),
                    HKHealthStore.notFromThisApp
                ])
            ),
            options: .cumulativeSum,
            anchorDate: Calendar.current.startOfDay(for: start),
            intervalComponents: DateComponents(day: 1)
        )
        var totals: [Date: Int] = [:]
        try await descriptor.result(for: healthStore).enumerateStatistics(from: start, to: end) { statistics, _ in
            if let sum = statistics.sumQuantity() {
                totals[statistics.startDate] = Int(sum.doubleValue(for: .count()))
            }
        }
        return totals
    }

    func changeNotifications() -> AsyncStream<Void> {
        healthStore.changeNotifications(for: [Self.stepCount])
    }

    private nonisolated func checkAvailable() throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitStepsServiceError.healthDataUnavailable
        }
    }
}
#endif
