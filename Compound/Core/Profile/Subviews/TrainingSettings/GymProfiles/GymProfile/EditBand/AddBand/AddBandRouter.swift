import SwiftUI

@MainActor
protocol AddBandRouter: GlobalRouter {
    
}

extension CoreRouter: AddBandRouter { }
