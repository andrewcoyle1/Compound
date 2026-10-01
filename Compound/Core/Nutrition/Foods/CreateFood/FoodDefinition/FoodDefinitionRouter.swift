import SwiftUI

@MainActor
protocol FoodDefinitionRouter: GlobalRouter {
    
}

extension CoreRouter: FoodDefinitionRouter { }
