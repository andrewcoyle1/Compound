import SwiftUI

@MainActor
protocol EditCableMachineRouter: GlobalRouter {
    func showEditWeightRangeView<Range: WeightRange>(delegate: EditWeightRangeDelegate<Range>)
    func showAddCableMachineRangeView(delegate: AddCableMachineRangeDelegate)

}

extension CoreRouter: EditCableMachineRouter { }
