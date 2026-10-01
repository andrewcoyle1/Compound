#if canImport(HealthKit)
import Foundation

/// An in-memory Apple Health. The anchor is the number of changes already handed out.
@MainActor
class MockHealthKitWeightService: HealthKitWeightService {
    private(set) var samples: [HealthKitWeightSample] = []
    private(set) var bodyFatSamples: [HealthKitBodyFatSample] = []
    private var changeLog: [(date: Date?, deleted: UUID?)] = []
    private var observers: [AsyncStream<Void>.Continuation] = []

    init(samples: [HealthKitWeightSample] = [], bodyFatSamples: [HealthKitBodyFatSample] = []) {
        samples.forEach { add($0) }
        bodyFatSamples.forEach { add($0) }
    }

    func add(_ sample: HealthKitWeightSample) {
        samples.append(sample)
        record(date: sample.date, deleted: nil)
    }

    func add(_ sample: HealthKitBodyFatSample) {
        bodyFatSamples.append(sample)
        record(date: sample.date, deleted: nil)
    }

    func delete(_ uuid: UUID) {
        samples.removeAll { $0.uuid == uuid }
        bodyFatSamples.removeAll { $0.uuid == uuid }
        record(date: nil, deleted: uuid)
    }

    private func record(date: Date?, deleted: UUID?) {
        changeLog.append((date, deleted))
        observers.forEach { $0.yield() }
    }

    func changes(after anchor: Data?) async throws -> HealthKitBodyChanges {
        let seen = anchor.flatMap { String(bytes: $0, encoding: .utf8) }.flatMap(Int.init) ?? 0
        let new = changeLog.dropFirst(seen)
        return HealthKitBodyChanges(
            addedDates: new.compactMap(\.date),
            deletedUUIDs: Set(new.compactMap(\.deleted)),
            anchor: Data(String(changeLog.count).utf8)
        )
    }

    func readWeightSamples(from start: Date, to end: Date) async throws -> [HealthKitWeightSample] {
        samples.filter { $0.date >= start && $0.date < end }
    }

    func readBodyFatSamples(from start: Date, to end: Date) async throws -> [HealthKitBodyFatSample] {
        bodyFatSamples.filter { $0.date >= start && $0.date < end }
    }

    func changeNotifications() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        observers.append(continuation)
        return stream
    }

    /// Like the real service, a sample this app writes is not read back.
    func saveWeightSample(weightKg: Double, date: Date) async throws -> UUID {
        UUID()
    }
}
#endif
