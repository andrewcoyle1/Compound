import SwiftUI

@MainActor
protocol EditFreeWeightRouter: GlobalRouter {
    func showAddFreeWeightView(delegate: AddFreeWeightDelegate)
}

extension CoreRouter: EditFreeWeightRouter { }
