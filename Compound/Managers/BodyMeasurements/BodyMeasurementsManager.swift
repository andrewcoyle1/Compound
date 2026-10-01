//
//  BodyMeasurementsManager.swift
//  Compound
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
        private var healthKitTask: Task<Void, Never>?
        private var isHealthKitImportRunning = false
        private var isHealthKitImportRequested = false
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
#if canImport(HealthKit)
        startHealthKitImport(userId: userId)
#endif
    }

    func signOut() {
#if canImport(HealthKit)
        healthKitTask?.cancel()
        healthKitTask = nil
#endif
        bodyMeasurementsSyncEngine.stopListening()
    }

    // MARK: CREATE
    func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws {
#if canImport(HealthKit)
        try await bodyMeasurementsSyncEngine.saveDocument(await exportedToHealthKit(bodyMeasurement))
#else
        try await bodyMeasurementsSyncEngine.saveDocument(bodyMeasurement)
#endif
    }

    // MARK: DELETE
    func deleteWeightEntry(entryId: String) async throws {
        try await bodyMeasurementsSyncEngine.deleteDocument(id: entryId)
    }

#if canImport(HealthKit)
    // MARK: HealthKit Import

    /// Imports what changed in Apple Health now, then again whenever Health reports a change,
    /// until sign-out. Call again after access is granted: queries started without it see nothing.
    /// `fromScratch` drops the anchor, re-reading all of Health, which is the only way to pick up
    /// history for a type whose access was granted after the anchor had moved on. Only entries
    /// that differ are written, so a re-read costs Firestore nothing when nothing changed.
    func startHealthKitImport(userId: String, fromScratch: Bool = false) {
        guard let healthKitService else { return }
        if fromScratch { UserDefaults.standard.removeObject(forKey: Self.anchorKey(userId)) }
        healthKitTask?.cancel()
        healthKitTask = Task { [weak self] in
            await self?.importHealthKitChanges(userId: userId)
            for await _ in healthKitService.changeNotifications() {
                await self?.importHealthKitChanges(userId: userId)
            }
        }
    }

    /// One run at a time: a second would read the collection before the first's writes land.
    /// A request during a run is folded into one more run after it.
    func importHealthKitChanges(userId: String) async {
        guard !isHealthKitImportRunning else {
            isHealthKitImportRequested = true
            return
        }
        isHealthKitImportRunning = true
        defer { isHealthKitImportRunning = false }
        repeat {
            isHealthKitImportRequested = false
            // A task of its own, so that it runs to the end. Each screen that shows this data
            // restarts the import as it opens, cancelling the loop that called this; a pass
            // cancelled with it stopped mid-read without storing its anchor, so the catch-up
            // began again from nothing on every launch.
            await Task { try? await self.importChanges(userId: userId) }.value
        } while isHealthKitImportRequested
    }

    private static func anchorKey(_ userId: String) -> String {
        "healthkit.bodyMeasurements.anchor.\(userId)"
    }

    /// Fetches only what changed since the stored anchor, then rebuilds the one Health entry for
    /// each day it touched: that day's lowest weigh-in with its latest body fat reading. The anchor
    /// is stored only once every write has succeeded, so a failure is retried next time.
    private func importChanges(userId: String) async throws {
        guard let healthKitService else { return }
        let anchorKey = Self.anchorKey(userId)
        let storedAnchor = UserDefaults.standard.data(forKey: anchorKey)
        let changes = try await healthKitService.changes(after: storedAnchor)

        let calendar = Calendar.current
        let entriesByDay = Dictionary(
            grouping: bodyMeasurements.filter { $0.authorId == userId && $0.deletedAt == nil }
        ) { calendar.startOfDay(for: $0.date) }
        let deletedDays = bodyMeasurements
            .filter { $0.source == .healthkit && $0.healthKitUUID.map(changes.deletedUUIDs.contains) == true }
            .map { calendar.startOfDay(for: $0.date) }
        let days = Set(changes.addedDates.map { calendar.startOfDay(for: $0) } + deletedDays)

        if let first = days.min(), let last = days.max(),
           let end = calendar.date(byAdding: .day, value: 1, to: last) {
            let lowestWeight = Dictionary(grouping: try await healthKitService.readWeightSamples(from: first, to: end)) {
                calendar.startOfDay(for: $0.date)
            }.compactMapValues { $0.min { $0.weightKg < $1.weightKg } }
            let latestBodyFat = Dictionary(grouping: try await healthKitService.readBodyFatSamples(from: first, to: end)) {
                calendar.startOfDay(for: $0.date)
            }.compactMapValues { $0.max { $0.date < $1.date } }

            for day in days.sorted() {
                let dayEntries = entriesByDay[day] ?? []
                if let entry = healthKitEntry(
                    userId: userId, day: day, dayEntries: dayEntries,
                    weight: lowestWeight[day], bodyFat: latestBodyFat[day]
                ) {
                    try await bodyMeasurementsSyncEngine.saveDocument(entry)
                }
            }
        }

        // Without read access HealthKit returns nothing rather than an error, and an anchor
        // stored then would skip the history once access is granted. So the first anchor is
        // kept only once Health has handed over something.
        if storedAnchor != nil || !changes.addedDates.isEmpty {
            UserDefaults.standard.set(changes.anchor, forKey: anchorKey)
        }
    }

    /// The day's Health entry as it should now read, or nil when nothing needs writing.
    private func healthKitEntry(
        userId: String,
        day: Date,
        dayEntries: [BodyMeasurementEntry],
        weight: HealthKitWeightSample?,
        bodyFat: HealthKitBodyFatSample?
    ) -> BodyMeasurementEntry? {
        let existing = dayEntries.first { $0.source == .healthkit }
        guard let weight else {
            // Every weigh-in that day was deleted from Health: clear it here too, keeping any
            // measurements added to the entry in the app.
            guard var entry = existing, entry.weightKg != nil else { return nil }
            entry.weightKg = nil
            entry.bodyFatPercentage = nil
            entry.healthKitUUID = nil
            return entry
        }
        // A weigh-in logged here that day already reads as low or lower.
        if existing == nil, dayEntries.contains(where: { ($0.weightKg ?? .infinity) <= weight.weightKg }) {
            return nil
        }
        // The id is derived from the day, so a run that cannot yet see the previous run's write,
        // or another device importing the same day, overwrites rather than duplicates.
        var entry = existing ?? BodyMeasurementEntry(
            id: "healthkit-\(userId)-\(Int(day.timeIntervalSince1970))",
            authorId: userId,
            date: weight.date,
            source: .healthkit,
            dateCreated: weight.date
        )
        // Same reading as last time: leave the weight alone, which keeps a weight the person
        // cleared here from coming back.
        if entry.healthKitUUID != weight.uuid {
            entry.weightKg = weight.weightKg
            entry.date = weight.date
            entry.healthKitUUID = weight.uuid
        }
        if let bodyFat {
            entry.bodyFatPercentage = bodyFat.bodyFatPercentage
        }
        return entry == existing ? nil : entry
    }

    /// A weigh-in logged here goes to Apple Health first, so the entry is written once with the
    /// sample's UUID rather than twice.
    private func exportedToHealthKit(_ entry: BodyMeasurementEntry) async -> BodyMeasurementEntry {
        guard let healthKitService,
              entry.source != .healthkit, entry.healthKitUUID == nil,
              let weightKg = entry.weightKg,
              let uuid = try? await healthKitService.saveWeightSample(weightKg: weightKg, date: entry.date)
        else { return entry }
        var exported = entry
        exported.healthKitUUID = uuid
        return exported
    }
#endif
}

extension CoreInteractor {
    // BodyMeasurementsManager

    var bodyMeasurements: [BodyMeasurementEntry] {
        bodyMeasurementsManager.bodyMeasurements
    }

    /// The latest weigh-in, or the weight given in onboarding when none has been logged. A goal
    /// set months after onboarding has to start from where the person is now.
    var currentWeightKilograms: Double? {
        bodyMeasurements
            .filter { $0.deletedAt == nil && $0.weightKg != nil }
            .max { $0.date < $1.date }?.weightKg
            ?? currentUser?.submittedWeightKilograms
    }

    /// CREATE
    func saveBodyMeasurement(bodyMeasurement: BodyMeasurementEntry) async throws {
        if bodyMeasurement.weightKg != nil {
            await requestBodyMeasurementHealthAccess()
        }
        try await bodyMeasurementsManager.saveBodyMeasurement(bodyMeasurement: bodyMeasurement)
    }

    /// Asks for Apple Health access to weight when weight is first logged or its history first
    /// opened, which is the moment the HIG names for it. Onboarding used to ask for everything up
    /// front. HealthKit shows nothing once the person has answered, so this is safe to repeat.
    private func requestBodyMeasurementHealthAccess() async {
        #if canImport(HealthKit)
        guard canRequestHealthDataAuthorisation() else { return }
        try? await requestHealthKitAuthorisation(for: .bodyMeasurements)
        #endif
    }

    /// DELETE
    func deleteWeightEntry(entryId: String) async throws {
        try await bodyMeasurementsManager.deleteWeightEntry(entryId: entryId)
    }

    /// Asks for access if not yet asked, then restarts the import so it runs with that access.
    func syncWeightFromHealthKit() async {
        #if canImport(HealthKit)
        guard let userId else { return }
        await requestBodyMeasurementHealthAccess()
        bodyMeasurementsManager.startHealthKitImport(userId: userId)
        #endif
    }

    /// As `syncWeightFromHealthKit`, re-reading all of Health: body fat access can be granted
    /// after weight's, and the anchor will already have passed that history.
    func backfillBodyFatFromHealthKit() async {
        #if canImport(HealthKit)
        guard let userId else { return }
        await requestBodyMeasurementHealthAccess()
        bodyMeasurementsManager.startHealthKitImport(userId: userId, fromScratch: true)
        #endif
    }

}
