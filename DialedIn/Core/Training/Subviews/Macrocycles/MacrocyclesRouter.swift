//
//  MacrocyclesRouter.swift
//  DialedIn
//

@MainActor
protocol MacrocyclesRouter: GlobalRouter {
    func showMacrocycleDetailView(delegate: MacrocycleDetailDelegate)
}

extension CoreRouter: MacrocyclesRouter { }
