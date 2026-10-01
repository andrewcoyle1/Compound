import SwiftUI

@MainActor
protocol WeeklyGoalRouter: GlobalRouter { }

extension CoreRouter: WeeklyGoalRouter { }
