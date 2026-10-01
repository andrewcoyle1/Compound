import SwiftUI

@MainActor
protocol GymProfilesRouter: GlobalRouter {
    func showGymProfileView(delegate: GymProfileDelegate)
}

extension CoreRouter: GymProfilesRouter { }
