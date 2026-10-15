//
//  FirestoreContractTests+CheckIn.swift
//  CompoundUnitTests
//
//  The weekly check-in's documents under the Firestore contract: the strategy settings
//  (`users/{uid}/nutrition_strategy_settings/nutrition_strategy_settings`), the check-in record
//  (`users/{uid}/check_in_record/check_in_record`), the logging break
//  (`users/{uid}/logging_break/logging_break`), one annotation per day
//  (`users/{uid}/nutrition_day_annotations/{day_key}`), and the Search tab's shortcut settings
//  (`users/{uid}/shortcut_settings/shortcut_settings`). All five decode with Swift's synthesized
//  decoder, so their only lenient paths are null optionals and whole-number doubles in an Int.
//  See FirestoreContractTests.swift.
//

import Foundation
import Testing
import FirebaseFirestore
@testable import Compound

extension FirestoreContractTests {

    /// Every manager here saves whole documents, which merge. The named fields are the ones
    /// `functions/coach.js` reads by name (`get_expenditure`, `get_check_ins`, `nutrition_day`),
    /// the `author_id` the rules check on create, and the ones the Flutter repository writes by
    /// name: `calculation_start_date` and `end_date` are deleted outright when cleared (a merge
    /// would keep the old value), and the record's two week starts are merged one at a time.
    static func checkInContracts() throws -> [Contract] {
        [
            try contract(
                NutritionStrategySettings.self, directory: "nutrition_strategy_settings",
                full: Samples.fullNutritionStrategySettings,
                minimal: NutritionStrategySettings(authorId: "user_contract_minimal"),
                namedFields: ([
                    .checkInWeekday, .calculationMode, .calculationStartDate, .stepInformedUpdates,
                    .estimationMethod, .bmrEquation
                ] as [NutritionStrategySettings.CodingKeys]).map(\.rawValue)
            ),
            try contract(
                CheckInRecord.self, directory: "check_in_record",
                full: Samples.fullCheckInRecord, minimal: CheckInRecord(authorId: "user_contract_minimal"),
                namedFields: ([
                    .id, .authorId, .lastCompletedWeekStart, .lastSkippedWeekStart
                ] as [CheckInRecord.CodingKeys]).map(\.rawValue)
            ),
            try contract(
                LoggingBreak.self, directory: "logging_break",
                full: Samples.fullLoggingBreak, minimal: Samples.minimalLoggingBreak,
                namedFields: ([.authorId, .startDate, .endDate] as [LoggingBreak.CodingKeys]).map(\.rawValue)
            ),
            try contract(
                NutritionDayAnnotation.self, directory: "nutrition_day_annotation",
                full: Samples.fullDayAnnotation, minimal: Samples.minimalDayAnnotation,
                namedFields: ([
                    .dayKey, .authorId, .isPartiallyLogged, .isFastingDay
                ] as [NutritionDayAnnotation.CodingKeys]).map(\.rawValue)
            ),
            try contract(
                ShortcutSettings.self, directory: "shortcut_settings",
                full: Samples.fullShortcutSettings, minimal: ShortcutSettings(authorId: "user_contract_minimal"),
                namedFields: []
            )
        ]
    }

    /// All four are CaseIterable.
    static func checkInEnums() -> [String: [String]] {
        [
            "ExpenditureEstimationMethod": ExpenditureEstimationMethod.allCases.map(\.rawValue),
            "BMREquation": BMREquation.allCases.map(\.rawValue),
            "ExpenditureCalculationMode": ExpenditureCalculationMode.allCases.map(\.rawValue),
            "ExpenditureAlgorithmVersion": ExpenditureAlgorithmVersion.allCases.map(\.rawValue)
        ]
    }

    @Test("Cunningham is stored under Katch-McArdle's raw value")
    func cunninghamKeepsTheOldRawValue() throws {
        let fixture = try Self.taggedFixture("nutrition_strategy_settings", "full")
        #expect(fixture["bmr_equation"] as? String == "katchMcArdle")
    }
}
