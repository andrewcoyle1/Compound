import SwiftUI

@MainActor
protocol EditPinLoadedMachineRouter: GlobalRouter {
    func showEditWeightRangeView<Range: WeightRange>(delegate: EditWeightRangeDelegate<Range>)
    func showAddPinLoadedMachineRangeView(delegate: AddPinLoadedMachineRangeDelegate)
}

extension CoreRouter: EditPinLoadedMachineRouter { }
