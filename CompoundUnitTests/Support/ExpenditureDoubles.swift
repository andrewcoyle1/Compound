//
//  ExpenditureDoubles.swift
//  CompoundUnitTests
//

import Foundation
@testable import Compound

extension ExpenditureEstimate {

    /// A plain adaptive estimate, for the screens that need one on their interactor and do not
    /// care what it says.
    static let stub = ExpenditureEstimate(
        day: Date(timeIntervalSince1970: 1_750_000_000),
        kcal: 2500,
        source: .adaptive,
        isProvisional: false,
        trendWeightKg: 80,
        weeklyTrendChangeKg: 0,
        loggedDays: 24,
        weighInCount: 20,
        windowDays: 28,
        stepAdjustmentKcal: 0
    )

    /// The same estimate with the pieces a test is asserting on swapped in.
    func with(
        kcal: Double? = nil,
        source: Source? = nil,
        isProvisional: Bool? = nil,
        loggedDays: Int? = nil,
        windowDays: Int? = nil,
        stepAdjustmentKcal: Double? = nil
    ) -> ExpenditureEstimate {
        ExpenditureEstimate(
            day: day,
            kcal: kcal ?? self.kcal,
            source: source ?? self.source,
            isProvisional: isProvisional ?? self.isProvisional,
            trendWeightKg: trendWeightKg,
            weeklyTrendChangeKg: weeklyTrendChangeKg,
            loggedDays: loggedDays ?? self.loggedDays,
            weighInCount: weighInCount,
            windowDays: windowDays ?? self.windowDays,
            stepAdjustmentKcal: stepAdjustmentKcal ?? self.stepAdjustmentKcal
        )
    }
}
