import SwiftUI

@MainActor
protocol SetTargetRouter: GlobalRouter {
    func showSetPlanDetailView(delegate: SetPlanDetailDelegate)
}

extension CoreRouter: SetTargetRouter { }
