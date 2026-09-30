import SwiftUI

@MainActor
protocol MesocycleIconRouter: GlobalRouter {
    func showMesocycleDesignView(delegate: MesocycleDesignDelegate)
}

extension CoreRouter: MesocycleIconRouter { }
