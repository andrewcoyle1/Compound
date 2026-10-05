//
//  EnergyBalanceRouter.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@MainActor
protocol EnergyBalanceRouter: GlobalRouter, AskCoachRouter {
    func showAddMealView(delegate: AddMealDelegate)
}

extension CoreRouter: EnergyBalanceRouter { }
