import SwiftUI

@MainActor
protocol AddFixedWeightBarRouter: GlobalRouter {
    
}

extension CoreRouter: AddFixedWeightBarRouter { }
