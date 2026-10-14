//
//  MacrocyclesRouter.swift
//  Compound
//

@MainActor
protocol MacrocyclesRouter: GlobalRouter {
    func showMacrocycleDetailView(delegate: MacrocycleDetailDelegate)
    func showImportProgramView(delegate: ImportProgramDelegate)
}

extension CoreRouter: MacrocyclesRouter { }
