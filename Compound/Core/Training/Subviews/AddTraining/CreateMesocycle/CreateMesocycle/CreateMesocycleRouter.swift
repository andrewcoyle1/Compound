import SwiftUI

@MainActor
protocol CreateMesocycleRouter: GlobalRouter {
    func showNameMesocycleView(delegate: NameMesocycleDelegate)
}

extension CoreRouter: CreateMesocycleRouter { }
