//
//  HeightRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

@MainActor
protocol HeightRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showWeightView(delegate: WeightDelegate)
}

extension CoreRouter: HeightRouter { }
