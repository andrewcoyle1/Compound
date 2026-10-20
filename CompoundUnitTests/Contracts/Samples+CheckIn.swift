//
//  Samples+CheckIn.swift
//  CompoundUnitTests
//
//  The fixed check-in samples behind contracts/firestore/{nutrition_strategy_settings,
//  check_in_record,logging_break,nutrition_day_annotation,shortcut_settings}. See
//  FirestoreContractTests.swift.
//

import Foundation
@testable import Compound

extension Samples {
    /// Every setting away from its default, and Cunningham, so its stored raw value is in the
    /// fixture.
    static let fullNutritionStrategySettings = NutritionStrategySettings(
        authorId: "user_contract_full",
        checkInWeekday: 5,
        fastCheckIn: true,
        partialLoggingEnabled: false,
        weighInEnabled: false,
        fastingEnabled: false,
        loggingBreakEnabled: false,
        estimationMethod: .bodyFatAware,
        calculationStartDate: date("2026-09-07T00:00:00.000Z"),
        bmrEquation: .cunningham,
        calculationMode: .fixed,
        algorithmVersion: .version1,
        stepInformedUpdates: true,
        predictiveGoalAdjustments: false
    )

    static let fullCheckInRecord = CheckInRecord(
        authorId: "user_contract_full",
        lastCompletedWeekStart: date("2026-10-05T00:00:00.000Z"),
        lastSkippedWeekStart: date("2026-09-28T00:00:00.000Z")
    )

    static let fullLoggingBreak = LoggingBreak(
        authorId: "user_contract_full",
        startDate: date("2026-08-10T09:15:30.250Z"),
        endDate: date("2026-08-24T18:40:00.500Z")
    )

    static let minimalLoggingBreak = LoggingBreak(
        authorId: "user_contract_minimal",
        startDate: date("2026-10-11T07:00:00.125Z")
    )

    static let fullDayAnnotation = NutritionDayAnnotation(
        dayKey: "2026-10-12",
        authorId: "user_contract_full",
        isPartiallyLogged: true,
        isFastingDay: true,
        dateModified: date("2026-10-13T08:30:15.750Z")
    )

    static let minimalDayAnnotation = NutritionDayAnnotation(
        dayKey: "2026-10-13",
        authorId: "user_contract_minimal",
        dateModified: date("2026-10-14T19:00:00.000Z")
    )

    static let fullShortcutSettings = ShortcutSettings(
        authorId: "user_contract_full",
        quickActionIds: ["log_meal", "start_workout", "browse_recipes"]
    )
}
