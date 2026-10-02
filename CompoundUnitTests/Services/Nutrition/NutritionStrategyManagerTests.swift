//
//  NutritionStrategyManagerTests.swift
//  CompoundUnitTests
//

import Testing
import Foundation
@testable import Compound

/// The three things the weekly check-in writes, through real sync engines with persistence off.
///
/// Every assertion goes through `eventually`: a sync engine applies a write when its listener
/// next emits, on its own task, so reading straight after `saveDocument` returns is reading the
/// state before the write.
@MainActor
struct NutritionStrategyManagerTests {

    private let userId = "user-1"

    private func annotation(
        _ dayKey: String,
        partial: Bool = false,
        fasting: Bool = false
    ) -> NutritionDayAnnotation {
        NutritionDayAnnotation(
            dayKey: dayKey,
            authorId: userId,
            isPartiallyLogged: partial,
            isFastingDay: fasting
        )
    }

    // MARK: - Day annotations

    @Test("Test An Annotation Is Saved Under Its Day Key")
    func testAnAnnotationIsSavedUnderItsDayKey() async throws {
        let manager = try await TestManagers.signedInNutritionStrategyManager()

        try await manager.saveDayAnnotation(annotation("2026-09-21", partial: true))

        #expect(await TestManagers.eventually { manager.dayAnnotations.count == 1 })
        #expect(manager.annotation(dayKey: "2026-09-21")?.isPartiallyLogged == true)
    }

    /// The id is the day key, so a second opinion about the same Tuesday replaces the first rather
    /// than joining it.
    @Test("Test Saving The Same Day Twice Replaces Rather Than Accumulates")
    func testSavingTheSameDayTwiceReplacesRatherThanAccumulates() async throws {
        let manager = try await TestManagers.signedInNutritionStrategyManager()

        try await manager.saveDayAnnotation(annotation("2026-09-21", partial: true))
        #expect(await TestManagers.eventually { manager.dayAnnotations.count == 1 })

        try await manager.saveDayAnnotation(annotation("2026-09-21", partial: false, fasting: true))

        #expect(await TestManagers.eventually { manager.annotation(dayKey: "2026-09-21")?.isFastingDay == true })
        #expect(manager.dayAnnotations.count == 1)
        #expect(manager.annotation(dayKey: "2026-09-21")?.isPartiallyLogged == false)
    }

    /// An annotation that says nothing is deleted rather than stored, so turning both toggles off
    /// leaves the day as it was before anyone asked.
    @Test("Test An Empty Annotation Clears The Day")
    func testAnEmptyAnnotationClearsTheDay() async throws {
        let manager = try await TestManagers.signedInNutritionStrategyManager(
            annotations: [annotation("2026-09-21", partial: true)]
        )

        try await manager.saveDayAnnotation(annotation("2026-09-21"))

        #expect(await TestManagers.eventually { manager.dayAnnotations.isEmpty })
    }

    @Test("Test Several Annotations Save Together")
    func testSeveralAnnotationsSaveTogether() async throws {
        let manager = try await TestManagers.signedInNutritionStrategyManager()

        try await manager.saveDayAnnotations([
            annotation("2026-09-21", partial: true),
            annotation("2026-09-22", fasting: true),
            annotation("2026-09-23")
        ])

        #expect(await TestManagers.eventually { manager.dayAnnotations.count == 2 })
        #expect(manager.annotation(dayKey: "2026-09-23") == nil)
    }

    // MARK: - Logging break

    @Test("Test Starting A Break Leaves It Open")
    func testStartingABreakLeavesItOpen() async throws {
        let manager = try await TestManagers.signedInNutritionStrategyManager()
        let start = Date(timeIntervalSince1970: 1_789_948_800)

        try await manager.startLoggingBreak(startDate: start)

        #expect(await TestManagers.eventually { manager.loggingBreak != nil })
        #expect(manager.loggingBreak?.startDate == start)
        #expect(manager.loggingBreak?.endDate == nil)
        #expect(manager.openLoggingBreak(on: start.addingTimeInterval(86_400)) != nil)
    }

    @Test("Test Ending A Break Closes It")
    func testEndingABreakClosesIt() async throws {
        let start = Date(timeIntervalSince1970: 1_789_948_800)
        let manager = try await TestManagers.signedInNutritionStrategyManager(
            loggingBreak: LoggingBreak(authorId: userId, startDate: start)
        )
        let end = start.addingTimeInterval(3 * 86_400)

        try await manager.endLoggingBreak(endDate: end)

        #expect(await TestManagers.eventually { manager.loggingBreak?.endDate != nil })
        #expect(manager.openLoggingBreak(on: end.addingTimeInterval(86_400)) == nil)
    }

    /// Ending a break that is already closed is a no-op, not a second end date.
    @Test("Test Ending A Closed Break Changes Nothing")
    func testEndingAClosedBreakChangesNothing() async throws {
        let start = Date(timeIntervalSince1970: 1_789_948_800)
        let end = start.addingTimeInterval(86_400)
        let manager = try await TestManagers.signedInNutritionStrategyManager(
            loggingBreak: LoggingBreak(authorId: userId, startDate: start, endDate: end)
        )

        try await manager.endLoggingBreak(endDate: end.addingTimeInterval(86_400))

        #expect(manager.loggingBreak?.endDate == end)
    }

    // MARK: - Check-in record

    /// The record is created on the first completion rather than at sign-in: no record means no
    /// check-in has ever been done, which is information an empty document would destroy.
    @Test("Test Completing Creates The Record")
    func testCompletingCreatesTheRecord() async throws {
        let manager = try await TestManagers.signedInNutritionStrategyManager()
        let weekStart = Date(timeIntervalSince1970: 1_789_948_800)

        #expect(manager.checkInRecord == nil)
        try await manager.markCheckInCompleted(weekStart: weekStart)

        #expect(await TestManagers.eventually { manager.checkInRecord?.lastCompletedWeekStart == weekStart })
        #expect(manager.checkInRecord?.lastSkippedWeekStart == nil)
    }

    /// Skipping is remembered separately, and neither write clears the other.
    @Test("Test Skipping And Completing Are Remembered Apart")
    func testSkippingAndCompletingAreRememberedApart() async throws {
        let weekStart = Date(timeIntervalSince1970: 1_789_948_800)
        let manager = try await TestManagers.signedInNutritionStrategyManager(
            record: CheckInRecord(authorId: "user-1", lastCompletedWeekStart: weekStart)
        )
        let nextWeek = weekStart.addingTimeInterval(7 * 86_400)

        try await manager.markCheckInSkipped(weekStart: nextWeek)

        #expect(await TestManagers.eventually { manager.checkInRecord?.lastSkippedWeekStart == nextWeek })
        #expect(manager.checkInRecord?.lastCompletedWeekStart == weekStart)
    }

    // MARK: - Sign out

    @Test("Test Signing Out Drops Everything")
    func testSigningOutDropsEverything() async throws {
        let manager = try await TestManagers.signedInNutritionStrategyManager(
            annotations: [annotation("2026-09-21", partial: true)],
            record: CheckInRecord(authorId: "user-1")
        )

        manager.signOut()

        #expect(await TestManagers.eventually { manager.dayAnnotations.isEmpty })
        #expect(manager.checkInRecord == nil)
    }
}
