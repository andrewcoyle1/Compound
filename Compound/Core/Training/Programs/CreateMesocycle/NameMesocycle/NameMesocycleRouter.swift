import SwiftUI

@MainActor
protocol NameMesocycleRouter {
    func showMesocycleIconView(delegate: MesocycleIconDelegate)
    /// Closes the cover when this is its first screen.
    func dismissEnvironment()
}

extension CoreRouter: NameMesocycleRouter { }
