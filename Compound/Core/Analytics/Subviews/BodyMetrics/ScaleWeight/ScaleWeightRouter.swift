import SwiftUI

@MainActor
protocol ScaleWeightRouter: GlobalRouter {
    func showLogWeightView()
}

extension CoreRouter: ScaleWeightRouter { }
