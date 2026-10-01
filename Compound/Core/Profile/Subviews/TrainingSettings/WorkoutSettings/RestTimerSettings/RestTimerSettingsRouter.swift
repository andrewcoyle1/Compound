import SwiftUI

@MainActor
protocol RestTimerSettingsRouter: GlobalRouter {
    func showTimerDurationView(delegate: TimerDurationDelegate)
}

extension CoreRouter: RestTimerSettingsRouter { }
