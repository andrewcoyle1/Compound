//
//  ActivityRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol ActivityRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showExpenditureView(delegate: ExpenditureDelegate)
}

extension CoreRouter: ActivityRouter { }
