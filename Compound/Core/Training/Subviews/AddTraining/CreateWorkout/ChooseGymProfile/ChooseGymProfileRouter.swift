import SwiftUI

@MainActor
protocol ChooseGymProfileRouter: GlobalRouter {
    func showDefineWorkoutWrapperView(delegate: DefineWorkoutWrapperDelegate)
    func showCreateGymProfileView(delegate: CreateGymProfileDelegate)
}

extension CoreRouter: ChooseGymProfileRouter { }
