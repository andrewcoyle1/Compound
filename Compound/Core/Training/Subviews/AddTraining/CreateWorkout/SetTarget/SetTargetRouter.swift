import SwiftUI

@MainActor
protocol SetTargetRouter: GlobalRouter {
    
}

extension CoreRouter: SetTargetRouter { }
