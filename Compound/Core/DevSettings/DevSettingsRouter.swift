//
//  DevSettingsRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol DevSettingsRouter: GlobalRouter {
    func switchToOnboardingModule()
}

extension CoreRouter: DevSettingsRouter { }
