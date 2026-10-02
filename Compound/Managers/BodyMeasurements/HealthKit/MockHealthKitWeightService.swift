#if canImport(HealthKit)
import Foundation

@MainActor
class MockHealthKitWeightService: HealthKitWeightService {
    private(set) var samples: [HealthKitWeightSample]
    private(set) var bodyFatSamples: [HealthKitBodyFatSample]

    init(samples: [HealthKitWeightSample] = [], bodyFatSamples: [HealthKitBodyFatSample] = []) {
        self.samples = samples
        self.bodyFatSamples = bodyFatSamples
    }

    func readWeightSamples(since: Date?) async throws -> [HealthKitWeightSample] {
        guard let since else { return samples }
        return samples.filter { $0.date > since }
    }

    func readBodyFatSamples(since: Date?) async throws -> [HealthKitBodyFatSample] {
        guard let since else { return bodyFatSamples }
        return bodyFatSamples.filter { $0.date > since }
    }

    func saveWeightSample(weightKg: Double, date: Date) async throws -> UUID {
        let sample = HealthKitWeightSample(uuid: UUID(), weightKg: weightKg, date: date)
        samples.append(sample)
        return sample.uuid
    }
}
#endif
