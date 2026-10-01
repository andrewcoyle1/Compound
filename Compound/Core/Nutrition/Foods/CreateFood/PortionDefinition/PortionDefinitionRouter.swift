import SwiftUI

@MainActor
protocol PortionDefinitionRouter: GlobalRouter {
    func showFoodDefinitionView(delegate: FoodDefinitionDelegate)
}

extension CoreRouter: PortionDefinitionRouter { }
