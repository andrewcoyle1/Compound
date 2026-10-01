import SwiftUI

@MainActor
protocol FoodPackagingRouter: GlobalRouter {
    func showPortionDefinitionView(delegate: PortionDefinitionDelegate)
}

extension CoreRouter: FoodPackagingRouter { }
