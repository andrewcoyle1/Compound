import SwiftUI

@MainActor
protocol TimerDurationRouter: GlobalRouter {
    
}

extension CoreRouter: TimerDurationRouter { }
