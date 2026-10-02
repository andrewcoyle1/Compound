//
//  MockHealthKitNutritionService.swift
//  Compound
//
//  Created by Andrew Coyle on 02/10/2026.
//
#if canImport(HealthKit)
import Foundation

struct MockNutritionSample: Equatable {
    var uuid = UUID()
    let nutrients: NutrientMap
    let date: Date
}

/// An in-memory Apple Health. The anchor is the number of changes already handed out.
@MainActor
class MockHealthKitNutritionService: HealthKitNutritionService {
    private(set) var samples: [MockNutritionSample] = []
    private var changeLog: [Date?] = []
    private var observers: [AsyncStream<Void>.Continuation] = []

    /// When set, the reads throw this, so the import's failure path has something to exercise.
    var errorToThrow: Error?

    init(samples: [MockNutritionSample] = []) {
        samples.forEach { add($0) }
    }

    func add(_ sample: MockNutritionSample) {
        samples.append(sample)
        record(sample.date)
    }

    func delete(_ uuid: UUID) {
        samples.removeAll { $0.uuid == uuid }
        record(nil)
    }

    private func record(_ date: Date?) {
        changeLog.append(date)
        observers.forEach { $0.yield() }
    }

    func changes(after anchor: Data?, since start: Date) async throws -> HealthKitDayChanges {
        if let errorToThrow { throw errorToThrow }
        let seen = anchor.flatMap { String(bytes: $0, encoding: .utf8) }.flatMap(Int.init) ?? 0
        let new = changeLog.dropFirst(seen)
        return HealthKitDayChanges(
            changedDays: Set(new.compactMap { $0 }.filter { $0 >= start }.map { Calendar.current.startOfDay(for: $0) }),
            hasDeletions: new.contains(nil),
            anchor: Data(String(changeLog.count).utf8)
        )
    }

    func dailyTotals(from start: Date, to end: Date) async throws -> [Date: NutrientMap] {
        if let errorToThrow { throw errorToThrow }
        return Dictionary(
            samples.filter { $0.date >= start && $0.date < end }.map { (Calendar.current.startOfDay(for: $0.date), $0.nutrients) },
            uniquingKeysWith: +
        )
    }

    func changeNotifications() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        observers.append(continuation)
        return stream
    }
}
#endif
