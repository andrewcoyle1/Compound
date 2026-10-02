#if canImport(HealthKit)
import Foundation

@MainActor
class MockHealthKitStepsService: HealthKitStepsService {
    private(set) var samples: [HealthKitStepsSample]

    /// When set, `readStepsSamples` and `saveStepsSample` throw this instead of returning,
    /// so `StepsManager`'s `catch { return }` paths have something to exercise. Nothing in
    /// production sets this — it is a test-only seam.
    var errorToThrow: Error?

    init(samples: [HealthKitStepsSample] = []) {
        self.samples = samples
    }

    func readStepsSamples(since: Date?, earliestDate: Date?) async throws -> [HealthKitStepsSample] {
        if let errorToThrow {
            throw errorToThrow
        }
        var filtered = samples
        if let since {
            filtered = filtered.filter { $0.date > since }
        }
        if let earliestDate {
            filtered = filtered.filter { $0.date >= earliestDate }
        }
        return filtered
    }

    func saveStepsSample(steps: Int, date: Date) async throws -> String {
        if let errorToThrow {
            throw errorToThrow
        }
        let sample = HealthKitStepsSample(id: UUID().uuidString, steps: steps, date: date)
        samples.append(sample)
        return sample.id
    }
}
#endif
