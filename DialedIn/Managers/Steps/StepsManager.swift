//
//  StepsManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 07/02/2026.
//

import Foundation

@Observable
@MainActor
class StepsManager {
    
    private let stepsSyncEngine: CollectionSyncEngine<StepsModel>
    
    #if canImport(HealthKit)
    private let healthKit: HealthKitStepsService?
    private var lastUserIdForSync: String?
    private var lastUserCreationDate: Date?
    private var isHealthKitSyncInProgress = false
    private let healthKitLastSyncKey = "healthkit.steps.lastSyncDate"
    #endif

    var stepsHistory: [StepsModel] {
        stepsSyncEngine.currentCollection
    }
    
    init(stepsSyncEngine: CollectionSyncEngine<StepsModel>, healthKitService: HealthKitStepsService) {
        self.stepsSyncEngine = stepsSyncEngine
        #if canImport(HealthKit)
        self.healthKit = healthKitService
        #endif
    }
    
    func signIn() async {
        await stepsSyncEngine.startListening()
    }
    
    func signOut() {
        stepsSyncEngine.stopListening()
    }

    func createStepsEntry(steps: StepsModel) async throws {
        try await stepsSyncEngine.saveDocument(steps)
    }
    
    #if canImport(HealthKit)
    // MARK: HealthKit Sync
    func syncWithHealthKit(userId: String) async {
        guard healthKit != nil else { return }
        guard !isHealthKitSyncInProgress else { return }
        isHealthKitSyncInProgress = true
        defer { isHealthKitSyncInProgress = false }

        do {
            try await importFromHealthKit(userId: userId)
        } catch {
            return
        }
    }

    /// Imports steps from HealthKit only when the local steps database is empty (one-time backfill).
    func backfillStepsFromHealthKit(userId: String, userCreationDate: Date? = nil) async {
        guard healthKit != nil else { return }
        guard !isHealthKitSyncInProgress else { return }

        guard stepsHistory.isEmpty else { return }

        isHealthKitSyncInProgress = true
        defer { isHealthKitSyncInProgress = false }

        lastUserCreationDate = userCreationDate ?? lastUserCreationDate

        do {
            try await importFromHealthKit(userId: userId)
        } catch {
            return
        }
    }

    private func importFromHealthKit(userId: String) async throws {
        guard let healthKit else { return }

        let lastSync = lastHealthKitSyncDate()
        let earliestDate = lastUserCreationDate.map { Calendar.current.startOfDay(for: $0) }
        let samples = try await healthKit.readStepsSamples(since: lastSync, earliestDate: earliestDate)
        guard !samples.isEmpty else { return }

        let existingIds = Set(stepsHistory.compactMap(\.healthKitId))
        let existingDayMaxs = existingDayMaxSteps(userId: userId, entries: stepsHistory)

        let newestDate = await processImportedStepsSamples(
            samples: samples,
            existingIds: existingIds,
            existingDayMaxs: existingDayMaxs,
            userId: userId,
            lastSync: lastSync
        )

        if let newestDate {
            setLastHealthKitSyncDate(newestDate)
        }
    }

    private func existingDayMaxSteps(userId: String, entries: [StepsModel]) -> [Date: Int] {
        Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
            .compactMapValues { dayEntries in
                dayEntries
                    .filter { $0.authorId == userId && $0.deletedAt == nil }
                    .max { $0.number < $1.number }?.number
            }
    }

    private func processImportedStepsSamples(
        samples: [HealthKitStepsSample],
        existingIds: Set<String>,
        existingDayMaxs: [Date: Int],
        userId: String,
        lastSync: Date?
    ) async -> Date? {
        var newestDate = lastSync
        for sample in samples {
            // Safe: `newestDate == nil ||` short-circuits before the unwrap.
            if newestDate == nil || sample.date > newestDate! {
                newestDate = sample.date
            }
            if existingIds.contains(sample.id) { continue }
            let sampleDay = Calendar.current.startOfDay(for: sample.date)
            if let existingDayMax = existingDayMaxs[sampleDay], existingDayMax >= sample.steps { continue }

            let steps = StepsModel(
                authorId: userId,
                number: sample.steps,
                date: sample.date,
                source: .healthkit,
                dateCreated: sample.date,
                dateModified: sample.date,
                healthKitId: sample.id
            )
            try? await stepsSyncEngine.saveDocument(steps)
        }
        return newestDate
    }

    private func exportToHealthKitIfNeeded(steps: StepsModel) async {
        guard let healthKit else { return }
        guard steps.source != .healthkit, steps.healthKitId == nil else { return }

        do {
            let uuid = try await healthKit.saveStepsSample(steps: steps.number, date: steps.date)
            let updatedEntry = StepsModel(
                id: steps.id,
                authorId: steps.authorId,
                number: steps.number,
                date: steps.date,
                source: steps.source,
                dateCreated: steps.dateCreated,
                dateModified: steps.dateModified,
                deletedAt: steps.deletedAt,
                healthKitId: uuid
            )

            try await stepsSyncEngine.saveDocument(updatedEntry)
        } catch {
            return
        }
    }

    private func lastHealthKitSyncDate() -> Date? {
        UserDefaults.standard.object(forKey: healthKitLastSyncKey) as? Date
    }

    private func setLastHealthKitSyncDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: healthKitLastSyncKey)
    }

    #endif
}

extension CoreInteractor {
    // StepsManager

    var stepsHistory: [StepsModel] {
        stepsManager.stepsHistory
    }

    /// CREATE
    func createStepsEntry(steps: StepsModel) async throws {
        try await stepsManager.createStepsEntry(steps: steps)
    }

    func backfillStepsFromHealthKit() async {
        guard let userId else { return }
        await stepsManager.backfillStepsFromHealthKit(userId: userId, userCreationDate: currentUser?.creationDate)
    }

}
