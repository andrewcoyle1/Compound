import SwiftUI

@MainActor
protocol MicrocycleVariationsRouter: GlobalRouter {
    /// A week's own targets, in the set-target editor.
    func showSetTargetView(delegate: SetTargetDelegate)
}

extension CoreRouter: MicrocycleVariationsRouter { }
