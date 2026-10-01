import SwiftUI

@MainActor
protocol MesocycleDisclosureGroupRouter: GlobalRouter {
    func showEditMesocycleView(delegate: EditMesocycleDelegate)
    func showShareToFollowerView(delegate: ShareToFollowerDelegate)
}

extension CoreRouter: MesocycleDisclosureGroupRouter { }
