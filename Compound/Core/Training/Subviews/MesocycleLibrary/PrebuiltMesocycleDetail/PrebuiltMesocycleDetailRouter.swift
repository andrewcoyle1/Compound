//
//  PrebuiltMesocycleDetailRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 25/09/2026.
//

@MainActor
protocol PrebuiltMesocycleDetailRouter: GlobalRouter {
    /// Restated so a test double's override is dispatched; `GlobalRouter` supplies the real one.
    func dismissScreen()
}

extension CoreRouter: PrebuiltMesocycleDetailRouter { }
