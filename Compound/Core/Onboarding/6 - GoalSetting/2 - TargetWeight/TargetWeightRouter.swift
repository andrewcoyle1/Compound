//
//  TargetWeightRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol TargetWeightRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showWeightRateView(delegate: WeightRateDelegate)
}

extension CoreRouter: TargetWeightRouter { }
