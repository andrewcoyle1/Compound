//
//  MesocycleLibraryRouter.swift
//  Compound
//
//  Created by Andrew Coyle on 27/11/2025.
//

import SwiftUI

@MainActor
protocol MesocycleLibraryRouter: GlobalRouter {
#if DEV || MOCK
func showDevSettingsView()
#endif
    func showMesocycleSettingsView(mesocycle: Binding<Mesocycle>)
    func showCreateMesocycleView(delegate: CreateMesocycleDelegate)
    func showEditMesocycleView(delegate: EditMesocycleDelegate)
    func showPrebuiltMesocycleDetailView(mesocycle: Mesocycle)
}

extension CoreRouter: MesocycleLibraryRouter { }
