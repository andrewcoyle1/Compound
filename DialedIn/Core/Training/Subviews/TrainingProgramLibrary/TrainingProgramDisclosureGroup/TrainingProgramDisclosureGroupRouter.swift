import SwiftUI

@MainActor
protocol TrainingProgramDisclosureGroupRouter: GlobalRouter {
    func showEditTrainingProgramView(delegate: EditTrainingProgramDelegate)
    func showShareToFollowerView(delegate: ShareToFollowerDelegate)
}

extension CoreRouter: TrainingProgramDisclosureGroupRouter { }
