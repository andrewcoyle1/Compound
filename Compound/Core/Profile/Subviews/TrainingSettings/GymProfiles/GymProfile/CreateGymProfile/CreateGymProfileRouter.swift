import SwiftUI

@MainActor
protocol CreateGymProfileRouter: GlobalRouter {
    func showGymProfileView(delegate: GymProfileDelegate)
}

extension CoreRouter: CreateGymProfileRouter { }
