import SwiftUI

@MainActor
protocol NameMesocycleRouter {
    func showMesocycleIconView(delegate: MesocycleIconDelegate)
}

extension CoreRouter: NameMesocycleRouter { }
