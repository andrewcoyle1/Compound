import SwiftUI

@MainActor
protocol CreateMesocycleRouter: GlobalRouter {
    func showNameMesocycleView(delegate: NameMesocycleDelegate)
    func showPrebuiltMesocycleDetailView(mesocycle: Mesocycle, onStarted: (@Sendable () -> Void)?)
}

extension CoreRouter: CreateMesocycleRouter { }
