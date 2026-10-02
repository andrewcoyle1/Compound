import SwiftUI

@MainActor
protocol EditBodyWeightRouter: GlobalRouter {
    func showAddBodyWeightView(delegate: AddBodyWeightDelegate)
}

extension CoreRouter: EditBodyWeightRouter { }
