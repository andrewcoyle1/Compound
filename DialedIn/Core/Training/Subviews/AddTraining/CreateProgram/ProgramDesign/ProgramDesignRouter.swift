import SwiftUI

@MainActor
protocol ProgramDesignRouter: GlobalRouter {
    func showRenameWorkoutTemplateModelView(delegate: RenameWorkoutTemplateModelDelegate)
    func showProgramSettingsView(program: Binding<TrainingProgram>)
    func showShareToFollowerView(delegate: ShareToFollowerDelegate)
}

extension CoreRouter: ProgramDesignRouter { }

extension CoreRouter {
    func showRenameWorkoutTemplateModelView(delegate: RenameWorkoutTemplateModelDelegate) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.renameWorkoutTemplateModelView(router: router, delegate: delegate)
        }
    }
}
