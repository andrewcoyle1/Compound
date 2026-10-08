import SwiftUI

@MainActor
protocol EditStackMachineRouter: GlobalRouter {
    func showEditWeightRangeView(delegate: EditWeightRangeDelegate)
    func showAddWeightStackView(delegate: AddWeightStackDelegate)
}

extension CoreRouter: EditStackMachineRouter { }
