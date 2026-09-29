//
//  PreferredDietRouter.swift
//  DialedIn
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol PreferredDietRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showCalorieFloorView(delegate: CalorieFloorDelegate)
    func showCalorieDistributionView(delegate: CalorieDistributionDelegate)
}

extension CoreRouter: PreferredDietRouter { }
