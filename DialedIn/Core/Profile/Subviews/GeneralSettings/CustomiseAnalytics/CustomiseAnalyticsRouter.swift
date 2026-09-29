import SwiftUI

@MainActor
protocol CustomiseAnalyticsRouter: GlobalRouter {
    
}

extension CoreRouter: CustomiseAnalyticsRouter { }
