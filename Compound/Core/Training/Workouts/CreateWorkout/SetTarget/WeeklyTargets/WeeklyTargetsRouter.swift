import SwiftUI

@MainActor
protocol WeeklyTargetsRouter: GlobalRouter {
    /// A week's own targets, in the set-target editor.
    func showSetTargetView(delegate: SetTargetDelegate)
}

extension CoreRouter: WeeklyTargetsRouter { }
