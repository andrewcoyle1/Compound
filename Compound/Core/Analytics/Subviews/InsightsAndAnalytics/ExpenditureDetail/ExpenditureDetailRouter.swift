//
//  ExpenditureDetailRouter.swift
//  Compound
//
//  Created by Cursor on 07/02/2026.
//

import SwiftUI

@MainActor
protocol ExpenditureDetailRouter: GlobalRouter {
    func showAccountView(delegate: AccountDelegate)
}

extension CoreRouter: ExpenditureDetailRouter { }
