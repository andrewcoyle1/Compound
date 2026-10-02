import SwiftUI

@MainActor
protocol EditBandRouter: GlobalRouter {
    func showAddBandView(delegate: AddBandDelegate)
}

extension CoreRouter: EditBandRouter { }
