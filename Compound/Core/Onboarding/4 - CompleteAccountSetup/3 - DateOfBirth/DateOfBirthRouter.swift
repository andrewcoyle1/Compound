//
//  DateOfBirthRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol DateOfBirthRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showHeightView(delegate: HeightDelegate)
}

extension CoreRouter: DateOfBirthRouter { }
