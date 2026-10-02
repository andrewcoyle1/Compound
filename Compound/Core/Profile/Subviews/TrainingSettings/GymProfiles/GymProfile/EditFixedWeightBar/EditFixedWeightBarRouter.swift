import SwiftUI

@MainActor
protocol EditFixedWeightBarRouter: GlobalRouter {
    func showAddFixedWeightBarView(delegate: AddFixedWeightBarDelegate)
}

extension CoreRouter: EditFixedWeightBarRouter { }
