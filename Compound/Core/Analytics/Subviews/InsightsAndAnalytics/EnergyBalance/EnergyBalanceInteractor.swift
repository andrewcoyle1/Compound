//
//  EnergyBalanceInteractor.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@MainActor
protocol EnergyBalanceInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var draftMeal: MealLogModel? { get }
    func getDailyTotals(dayKey: String) throws -> DailyMacroTarget
    func getDailyTotals(startDayKey: String, endDayKey: String) throws -> [(dayKey: String, totals: DailyMacroTarget)]
    func estimateTDEE(user: UserModel?) -> Double
    var expenditureHistory: [ExpenditureEstimate] { get }
}

extension CoreInteractor: EnergyBalanceInteractor { }
