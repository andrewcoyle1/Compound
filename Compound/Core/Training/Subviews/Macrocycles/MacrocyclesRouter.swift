//
//  MacrocyclesRouter.swift
//  Compound
//

@MainActor
protocol MacrocyclesRouter: GlobalRouter {
    func showMacrocycleDetailView(delegate: MacrocycleDetailDelegate)
}

extension CoreRouter: MacrocyclesRouter { }
