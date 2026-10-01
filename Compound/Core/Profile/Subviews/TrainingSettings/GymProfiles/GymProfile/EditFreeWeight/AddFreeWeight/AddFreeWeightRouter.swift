import SwiftUI

@MainActor
protocol AddFreeWeightRouter: GlobalRouter {
    
}

extension CoreRouter: AddFreeWeightRouter { }
