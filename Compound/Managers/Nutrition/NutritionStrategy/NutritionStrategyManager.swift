//
//  NutritionStrategyManager.swift
//  Compound
//

import Foundation

/// The three things the weekly check-in writes: day annotations, the logging break, and the
/// record of which weeks have been dealt with.
///
/// Kept apart from `NutritionStrategySettingsManager`, which owns the settings document the user
/// edits on the Strategy screen. These are the *consequences* of those settings rather than the
/// settings themselves, and three more engines on that manager would have pushed one file past
/// the point where either half could be read on its own.
@Observable
@MainActor
class NutritionStrategyManager {

    private let dayAnnotationSyncEngine: CollectionSyncEngine<NutritionDayAnnotation>
    private let loggingBreakSyncEngine: DocumentSyncEngine<LoggingBreak>
    private let checkInRecordSyncEngine: DocumentSyncEngine<CheckInRecord>
    private var userId: String?

    var dayAnnotations: [NutritionDayAnnotation] {
        dayAnnotationSyncEngine.currentCollection
    }

    /// The break document, open or closed. Ask `openLoggingBreak` when the question is whether
    /// logging is paused right now.
    var loggingBreak: LoggingBreak? {
        loggingBreakSyncEngine.currentDocument
    }

    var checkInRecord: CheckInRecord? {
        checkInRecordSyncEngine.currentDocument
    }

    init(
        dayAnnotationSyncEngine: CollectionSyncEngine<NutritionDayAnnotation>,
        loggingBreakSyncEngine: DocumentSyncEngine<LoggingBreak>,
        checkInRecordSyncEngine: DocumentSyncEngine<CheckInRecord>
    ) {
        self.dayAnnotationSyncEngine = dayAnnotationSyncEngine
        self.loggingBreakSyncEngine = loggingBreakSyncEngine
        self.checkInRecordSyncEngine = checkInRecordSyncEngine
    }

    // MARK: - Lifecycle

    /// Neither document is created on sign-in.
    ///
    /// Unlike the settings document, which has to exist for the Strategy screen to have anything
    /// to edit, these two are absences with meaning: no break document means no break, and no
    /// record means no check-in has ever been done. Writing empty ones on day one would only make
    /// every reader unwrap a value that says nothing.
    func signIn(userId: String) async throws {
        self.userId = userId
        await dayAnnotationSyncEngine.startListening()
        try await loggingBreakSyncEngine.startListening(documentId: LoggingBreak.documentId)
        try await checkInRecordSyncEngine.startListening(documentId: CheckInRecord.documentId)
    }

    func signOut() {
        userId = nil
        dayAnnotationSyncEngine.stopListening()
        loggingBreakSyncEngine.stopListening()
        checkInRecordSyncEngine.stopListening()
    }

    // MARK: - Day annotations

    func annotation(dayKey: String) -> NutritionDayAnnotation? {
        dayAnnotations.first { $0.dayKey == dayKey }
    }

    /// Saves one annotation, replacing any the day already had.
    ///
    /// An annotation that says nothing is deleted rather than stored, so turning both toggles back
    /// off leaves the day as it was before anyone asked about it.
    func saveDayAnnotation(_ annotation: NutritionDayAnnotation) async throws {
        if annotation.isEmpty {
            try await clearDayAnnotation(dayKey: annotation.dayKey)
        } else {
            try await dayAnnotationSyncEngine.saveDocument(annotation)
        }
    }

    func saveDayAnnotations(_ annotations: [NutritionDayAnnotation]) async throws {
        for annotation in annotations {
            try await saveDayAnnotation(annotation)
        }
    }

    /// Deleting a day that was never annotated is a no-op rather than an error: the check-in
    /// writes every row it showed, and most rows are untouched.
    func clearDayAnnotation(dayKey: String) async throws {
        guard annotation(dayKey: dayKey) != nil else { return }
        try await dayAnnotationSyncEngine.deleteDocument(id: dayKey)
    }

    // MARK: - Logging break

    /// The break that is paused right now, if there is one.
    func openLoggingBreak(on date: Date = .now) -> LoggingBreak? {
        guard let loggingBreak = loggingBreak, loggingBreak.isOpen(on: date) else { return nil }
        return loggingBreak
    }

    func startLoggingBreak(startDate: Date = .now) async throws {
        guard let userId else { return }
        try await loggingBreakSyncEngine.saveDocument(
            LoggingBreak(authorId: userId, startDate: startDate, endDate: nil)
        )
    }

    /// Ends the open break at `endDate`. With no open break there is nothing to end.
    func endLoggingBreak(endDate: Date = .now) async throws {
        guard var loggingBreak = loggingBreak, loggingBreak.endDate == nil else { return }
        loggingBreak.endDate = endDate
        try await loggingBreakSyncEngine.saveDocument(loggingBreak)
    }

    // MARK: - Check-in record

    func markCheckInCompleted(weekStart: Date) async throws {
        try await saveRecord { record in
            record.lastCompletedWeekStart = weekStart
        }
    }

    func markCheckInSkipped(weekStart: Date) async throws {
        try await saveRecord { record in
            record.lastSkippedWeekStart = weekStart
        }
    }

    /// Reads the record, mutates it and writes it back, creating one the first time.
    private func saveRecord(_ mutate: (inout CheckInRecord) -> Void) async throws {
        guard let userId else { return }
        var record = checkInRecord ?? CheckInRecord(authorId: userId)
        mutate(&record)
        try await checkInRecordSyncEngine.saveDocument(record)
    }
}

extension CoreInteractor {
    // MARK: NutritionStrategyManager

    var nutritionDayAnnotations: [NutritionDayAnnotation] {
        nutritionStrategyManager.dayAnnotations
    }

    var loggingBreak: LoggingBreak? {
        nutritionStrategyManager.loggingBreak
    }

    var openLoggingBreak: LoggingBreak? {
        nutritionStrategyManager.openLoggingBreak()
    }

    var checkInRecord: CheckInRecord? {
        nutritionStrategyManager.checkInRecord
    }

    func nutritionDayAnnotation(dayKey: String) -> NutritionDayAnnotation? {
        nutritionStrategyManager.annotation(dayKey: dayKey)
    }

    func saveNutritionDayAnnotations(_ annotations: [NutritionDayAnnotation]) async throws {
        try await nutritionStrategyManager.saveDayAnnotations(annotations)
    }

    func startLoggingBreak() async throws {
        try await nutritionStrategyManager.startLoggingBreak()
    }

    func endLoggingBreak() async throws {
        try await nutritionStrategyManager.endLoggingBreak()
    }

    func markCheckInCompleted(weekStart: Date) async throws {
        try await nutritionStrategyManager.markCheckInCompleted(weekStart: weekStart)
    }

    func markCheckInSkipped(weekStart: Date) async throws {
        try await nutritionStrategyManager.markCheckInSkipped(weekStart: weekStart)
    }
}
