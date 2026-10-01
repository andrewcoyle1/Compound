//
//  StepsManager.swift
//  Compound
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
    private var healthKitTask: Task<Void, Never>?
    private var isHealthKitImportRunning = false
    private var isHealthKitImportRequested = false
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
    
    /// - Parameter importSince: steps before this, usually the account's creation date, are not
    ///   imported. A year back when nil.
    func signIn(userId: String, importSince: Date?) async {
        await stepsSyncEngine.startListening()
        #if canImport(HealthKit)
        startHealthKitImport(userId: userId, since: importSince)
        #endif
    }
    
    func signOut() {
        #if canImport(HealthKit)
        healthKitTask?.cancel()
        healthKitTask = nil
        #endif
        stepsSyncEngine.stopListening()
    }

    func createStepsEntry(steps: StepsModel) async throws {
        try await stepsSyncEngine.saveDocument(steps)
    }
    
    #if canImport(HealthKit)
    // MARK: HealthKit Import

    /// Imports what changed in Apple Health now, then again whenever Health reports a change,
    /// until sign-out. Call again after access is granted: queries started without it see nothing.
    /// `fromScratch` drops the anchor and recounts every day; only days whose total differs are
    /// written, so that costs Firestore nothing when nothing changed.
    func startHealthKitImport(userId: String, since: Date?, fromScratch: Bool = false) {
        guard let healthKit else { return }
        if fromScratch { UserDefaults.standard.removeObject(forKey: Self.anchorKey(userId)) }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: since ?? calendar.date(byAdding: .year, value: -1, to: .now) ?? .now)
        healthKitTask?.cancel()
        healthKitTask = Task { [weak self] in
            await self?.importHealthKitChanges(userId: userId, since: start)
            for await _ in healthKit.changeNotifications() {
                await self?.importHealthKitChanges(userId: userId, since: start)
            }
        }
    }

    /// One run at a time: a second would read the history before the first's writes land.
    /// A request during a run is folded into one more run after it.
    func importHealthKitChanges(userId: String, since start: Date) async {
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
            await Task { try? await self.importChanges(userId: userId, since: start) }.value
        } while isHealthKitImportRequested
    }

    private static func anchorKey(_ userId: String) -> String {
        "healthkit.steps.anchor.\(userId)"
    }

    /// Fetches only what changed since the stored anchor, then rewrites the total of each day it
    /// touched. The anchor is stored only once every write has succeeded, so a failure is retried.
    private func importChanges(userId: String, since start: Date) async throws {
        guard let healthKit else { return }
        let anchorKey = Self.anchorKey(userId)
        let storedAnchor = UserDefaults.standard.data(forKey: anchorKey)
        let changes = try await healthKit.changes(after: storedAnchor, since: start)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let first = changes.hasDeletions ? start : changes.changedDays.min()
        let last = changes.hasDeletions ? today : changes.changedDays.max()
        if let first, let last, let end = calendar.date(byAdding: .day, value: 1, to: last) {
            let totals = try await healthKit.dailySteps(from: first, to: end)
            let days = changes.hasDeletions ? Set(totals.keys).union(healthKitDays(from: first)) : changes.changedDays
            let entriesByDay = Dictionary(
                grouping: stepsHistory.filter { $0.authorId == userId && $0.deletedAt == nil }
            ) { calendar.startOfDay(for: $0.date) }

            for day in days.sorted() {
                if let entry = healthKitEntry(userId: userId, day: day, dayEntries: entriesByDay[day] ?? [], total: totals[day] ?? 0) {
                    try await stepsSyncEngine.saveDocument(entry)
                }
            }
        }

        // Without read access HealthKit returns nothing rather than an error, and an anchor
        // stored then would skip the history once access is granted. So the first anchor is
        // kept only once Health has handed over something.
        if storedAnchor != nil || !changes.changedDays.isEmpty {
            UserDefaults.standard.set(changes.anchor, forKey: anchorKey)
        }
    }

    /// Days already holding an imported total, which a deletion may have changed.
    private func healthKitDays(from start: Date) -> [Date] {
        stepsHistory
            .filter { $0.source == .healthkit && $0.deletedAt == nil && $0.date >= start }
            .map { Calendar.current.startOfDay(for: $0.date) }
    }

    /// The day's Health entry as it should now read, or nil when nothing needs writing.
    private func healthKitEntry(userId: String, day: Date, dayEntries: [StepsModel], total: Int) -> StepsModel? {
        let existing = dayEntries.first { $0.source == .healthkit }
        if let existing {
            guard existing.number != total else { return nil }
            var entry = existing
            entry.number = total
            entry.dateModified = .now
            return entry
        }
        // Nothing to add, or a count entered here that day is already as high.
        guard total > 0, !dayEntries.contains(where: { $0.number >= total }) else { return nil }
        // The id is derived from the day, so a run that cannot yet see the previous run's write,
        // or another device importing the same day, overwrites rather than duplicates.
        return StepsModel(
            id: "healthkit-steps-\(Int(day.timeIntervalSince1970))",
            authorId: userId,
            number: total,
            date: day,
            source: .healthkit,
            dateCreated: .now,
            dateModified: .now
        )
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

    /// Restarts the import so it runs with whatever access the person has just granted.
    /// `fromScratch` recounts every day rather than only those Health reports as changed.
    func syncStepsFromHealthKit(fromScratch: Bool = false) async {
        #if canImport(HealthKit)
        guard let userId else { return }
        stepsManager.startHealthKitImport(userId: userId, since: currentUser?.creationDate, fromScratch: fromScratch)
        #endif
    }

}
