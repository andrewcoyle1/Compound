//
//  BodyMeasurementsManager.swift
//  DialedIn
//
//  Created by Andrew Coyle on 20/10/2025.
//

import Foundation

@Observable
@MainActor
class BodyMeasurementsManager {
    
    private let bodyMeasurementsSyncEngine: CollectionSyncEngine<BodyMeasurementEntry>
    #if canImport(HealthKit)
        private let healthKitService: HealthKitWeightService?
        private var lastUserIdForSync: String?
        private var isHealthKitSyncInProgress = false
        private let healthKitLastSyncKey = "healthkit.weight.lastSyncDate"
        private let healthKitBodyFatLastSyncKey = "healthkit.bodyfat.lastSyncDate"
    #endif

    var bodyMeasurements: [BodyMeasurementEntry] {
        bodyMeasurementsSyncEngine.currentCollection
    }
    
    init(
        bodyMeasurementsSyncEngine: CollectionSyncEngine<BodyMeasurementEntry>,
        healthKitService: HealthKitWeightService
    ) {
        self.bodyMeasurementsSyncEngine = bodyMeasurementsSyncEngine
#if canImport(HealthKit)
        self.healthKitService = healthKitService
#endif
    }

    // MARK: - Lifecycle

    func signIn(userId: String) async {
        await bodyMeasurementsSyncEngine.startListening { query in
            query.where("author_id", isEqualTo: userId)
        }
    }

    func signOut() {
        bodyMeasurementsSyncEngine.stopListening()
    }

    // MARK: CREATE
    func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws {
        try await bodyMeasurementsSyncEngine.saveDocument(bodyMeasurement)
#if canImport(HealthKit)
        lastUserIdForSync = bodyMeasurement.authorId
        await exportToHealthKitIfNeeded(entry: bodyMeasurement)
#endif
    }

    // MARK: DELETE
    func deleteWeightEntry(entryId: String) async throws {
        try await bodyMeasurementsSyncEngine.deleteDocument(id: entryId)
    }

#if canImport(HealthKit)
    // MARK: HealthKit Sync
    func syncWithHealthKit(userId: String) async {
        guard healthKitService != nil else { return }
        guard !isHealthKitSyncInProgress else { return }
        isHealthKitSyncInProgress = true
        defer { isHealthKitSyncInProgress = false }

        do {
            try await importFromHealthKit(userId: userId)
        } catch {
            return
        }
    }

    func backfillBodyFatFromHealthKit(userId: String) async {
        guard healthKitService != nil else { return }
        guard !isHealthKitSyncInProgress else { return }
        isHealthKitSyncInProgress = true
        defer { isHealthKitSyncInProgress = false }

        do {
            try await importBodyFatFromHealthKit(userId: userId, existingEntries: self.bodyMeasurements, forceFullSync: true)
        } catch {
            return
        }
    }

    private func importFromHealthKit(userId: String) async throws {
        guard let healthKitService else { return }

        let lastSync = lastHealthKitSyncDate()
        let samples = try await healthKitService.readWeightSamples(since: lastSync)
        guard !samples.isEmpty else { return }

        let consolidatedSamples = consolidateWeightSamplesByDay(samples)
        let existingEntries = self.bodyMeasurements
        let existingUUIDs = Set(existingEntries.compactMap(\.healthKitUUID))
        let existingDayMins = existingDayMinWeights(userId: userId, entries: existingEntries)

        let newestDate = await processImportedWeightSamples(
            consolidatedSamples: consolidatedSamples,
            existingUUIDs: existingUUIDs,
            existingDayMins: existingDayMins,
            userId: userId,
            lastSync: lastSync
        )

        if let newestDate {
            setLastHealthKitSyncDate(newestDate)
        }

        let refreshedEntries = self.bodyMeasurements
        try await importBodyFatFromHealthKit(
            userId: userId,
            existingEntries: refreshedEntries,
            forceFullSync: refreshedEntries.contains { $0.source == .healthkit && $0.deletedAt == nil && $0.bodyFatPercentage == nil }
        )
    }

    private func consolidateWeightSamplesByDay(_ samples: [HealthKitWeightSample]) -> [HealthKitWeightSample] {
        let samplesByDay = Dictionary(grouping: samples) { Calendar.current.startOfDay(for: $0.date) }
        return samplesByDay.compactMap { (_, daySamples) in daySamples.min { $0.weightKg < $1.weightKg } }
    }

    private func existingDayMinWeights(userId: String, entries: [BodyMeasurementEntry]) -> [Date: Double] {
        Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
            .compactMapValues { dayEntries in
                dayEntries
                    .filter { $0.authorId == userId && $0.deletedAt == nil && $0.weightKg != nil }
                    .min { lhs, rhs in
                        guard let lhsWeight = lhs.weightKg, let rhsWeight = rhs.weightKg else { return false }
                        return lhsWeight < rhsWeight
                    }?.weightKg
            }
    }

    private func processImportedWeightSamples(
        consolidatedSamples: [HealthKitWeightSample],
        existingUUIDs: Set<UUID>,
        existingDayMins: [Date: Double],
        userId: String,
        lastSync: Date?
    ) async -> Date? {
        var newestDate = lastSync
        for sample in consolidatedSamples {
            // Safe: `newestDate == nil ||` short-circuits before the unwrap.
            if newestDate == nil || sample.date > newestDate! {
                newestDate = sample.date
            }
            if existingUUIDs.contains(sample.uuid) { continue }
            let sampleDay = Calendar.current.startOfDay(for: sample.date)
            if let existingDayMin = existingDayMins[sampleDay], existingDayMin <= sample.weightKg { continue }

            let entry = BodyMeasurementEntry(
                authorId: userId,
                weightKg: sample.weightKg,
                date: sample.date,
                source: .healthkit,
                notes: nil,
                dateCreated: sample.date,
                deletedAt: nil,
                healthKitUUID: sample.uuid
            )
            try? await self.saveBodyMeasurement(bodyMeasurement: entry)
        }
        return newestDate
    }

    private func importBodyFatFromHealthKit(
        userId: String,
        existingEntries: [BodyMeasurementEntry],
        forceFullSync: Bool
    ) async throws {
        guard let healthKitService else { return }

        let since = forceFullSync ? nil : lastHealthKitBodyFatSyncDate()
        let samples = try await healthKitService.readBodyFatSamples(since: since)
        guard !samples.isEmpty else { return }

        let consolidatedSamples = consolidateBodyFatSamplesByDay(samples)
        let entriesByDay = Dictionary(grouping: existingEntries) { Calendar.current.startOfDay(for: $0.date) }

        let newestDate = await processBodyFatSamples(
            consolidatedSamples: consolidatedSamples,
            entriesByDay: entriesByDay,
            userId: userId,
            since: since
        )

        if let newestDate {
            setLastHealthKitBodyFatSyncDate(newestDate)
        }
    }

    private func consolidateBodyFatSamplesByDay(_ samples: [HealthKitBodyFatSample]) -> [HealthKitBodyFatSample] {
        let samplesByDay = Dictionary(grouping: samples) { Calendar.current.startOfDay(for: $0.date) }
        return samplesByDay.compactMap { (_, daySamples) in daySamples.max { $0.date < $1.date } }
    }

    private func processBodyFatSamples(
        consolidatedSamples: [HealthKitBodyFatSample],
        entriesByDay: [Date: [BodyMeasurementEntry]],
        userId: String,
        since: Date?
    ) async -> Date? {
        var newestDate = since
        for sample in consolidatedSamples {
            // Safe: `newestDate == nil ||` short-circuits before the unwrap.
            if newestDate == nil || sample.date > newestDate! {
                newestDate = sample.date
            }
            let sampleDay = Calendar.current.startOfDay(for: sample.date)
            guard let dayEntries = entriesByDay[sampleDay],
                  let entryToUpdate = dayEntries.first(where: {
                      $0.authorId == userId && $0.deletedAt == nil && $0.source == .healthkit
                  }),
                  entryToUpdate.bodyFatPercentage == nil
            else { continue }

            let updatedEntry = entryWithBodyFat(entryToUpdate, bodyFatPercentage: sample.bodyFatPercentage)
            
            try? await self.saveBodyMeasurement(bodyMeasurement: updatedEntry)
        }
        return newestDate
    }

    private func entryWithBodyFat(_ entry: BodyMeasurementEntry, bodyFatPercentage: Double?) -> BodyMeasurementEntry {
        BodyMeasurementEntry(
            id: entry.id,
            authorId: entry.authorId,
            weightKg: entry.weightKg,
            bodyFatPercentage: bodyFatPercentage,
            neckCircumference: entry.neckCircumference,
            shoulderCircumference: entry.shoulderCircumference,
            bustCircumference: entry.bustCircumference,
            chestCircumference: entry.chestCircumference,
            waistCircumference: entry.waistCircumference,
            hipCircumference: entry.hipCircumference,
            leftBicepCircumference: entry.leftBicepCircumference,
            rightBicepCircumference: entry.rightBicepCircumference,
            leftForearmCircumference: entry.leftForearmCircumference,
            rightForearmCircumference: entry.rightForearmCircumference,
            leftWristCircumference: entry.leftWristCircumference,
            rightWristCircumference: entry.rightWristCircumference,
            leftThighCircumference: entry.leftThighCircumference,
            rightThighCircumference: entry.rightThighCircumference,
            leftCalfCircumference: entry.leftCalfCircumference,
            rightCalfCircumference: entry.rightCalfCircumference,
            leftAnkleCircumference: entry.leftAnkleCircumference,
            rightAnkleCircumference: entry.rightAnkleCircumference,
            progressPhotoURLs: entry.progressPhotoURLs,
            date: entry.date,
            source: entry.source,
            notes: entry.notes,
            dateCreated: entry.dateCreated,
            deletedAt: entry.deletedAt,
            healthKitUUID: entry.healthKitUUID
        )
    }

    private func exportToHealthKitIfNeeded(entry: BodyMeasurementEntry) async {
        guard let healthKitService else { return }
        guard entry.source != .healthkit, entry.healthKitUUID == nil else { return }
        guard let weightKg = entry.weightKg else { return }

        do {
            let uuid = try await healthKitService.saveWeightSample(weightKg: weightKg, date: entry.date)
            let updatedEntry = BodyMeasurementEntry(
                id: entry.id,
                authorId: entry.authorId,
                weightKg: weightKg,
                bodyFatPercentage: entry.bodyFatPercentage,
                neckCircumference: entry.neckCircumference,
                shoulderCircumference: entry.shoulderCircumference,
                bustCircumference: entry.bustCircumference,
                chestCircumference: entry.chestCircumference,
                waistCircumference: entry.waistCircumference,
                hipCircumference: entry.hipCircumference,
                leftBicepCircumference: entry.leftBicepCircumference,
                rightBicepCircumference: entry.rightBicepCircumference,
                leftForearmCircumference: entry.leftForearmCircumference,
                rightForearmCircumference: entry.rightForearmCircumference,
                leftWristCircumference: entry.leftWristCircumference,
                rightWristCircumference: entry.rightWristCircumference,
                leftThighCircumference: entry.leftThighCircumference,
                rightThighCircumference: entry.rightThighCircumference,
                leftCalfCircumference: entry.leftCalfCircumference,
                rightCalfCircumference: entry.rightCalfCircumference,
                leftAnkleCircumference: entry.leftAnkleCircumference,
                rightAnkleCircumference: entry.rightAnkleCircumference,
                progressPhotoURLs: entry.progressPhotoURLs,
                date: entry.date,
                source: entry.source,
                notes: entry.notes,
                dateCreated: entry.dateCreated,
                deletedAt: entry.deletedAt,
                healthKitUUID: uuid
            )

            try? await self.saveBodyMeasurement(bodyMeasurement: updatedEntry)
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

    private func lastHealthKitBodyFatSyncDate() -> Date? {
        UserDefaults.standard.object(forKey: healthKitBodyFatLastSyncKey) as? Date
    }

    private func setLastHealthKitBodyFatSyncDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: healthKitBodyFatLastSyncKey)
    }
#endif
}

extension CoreInteractor {
    // BodyMeasurementsManager

    var bodyMeasurements: [BodyMeasurementEntry] {
        bodyMeasurementsManager.bodyMeasurements
    }

    /// CREATE
    func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws {
        try await bodyMeasurementsManager.saveBodyMeasurement(bodyMeasurement: bodyMeasurement)
    }

    /// DELETE
    func deleteWeightEntry(entryId: String) async throws {
        try await bodyMeasurementsManager.deleteWeightEntry(entryId: entryId)
    }

    func backfillBodyFatFromHealthKit() async {
        guard let userId else { return }
        await bodyMeasurementsManager.backfillBodyFatFromHealthKit(userId: userId)
    }

}
