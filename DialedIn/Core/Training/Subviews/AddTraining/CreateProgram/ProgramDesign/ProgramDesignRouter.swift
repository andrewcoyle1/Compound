import SwiftUI

@MainActor
protocol ProgramDesignRouter: GlobalRouter {
    func showRenameWorkoutTemplateModelView(delegate: RenameWorkoutTemplateModelDelegate)
    func showProgramSettingsView(program: Binding<TrainingProgram>)
}

extension CoreRouter: ProgramDesignRouter { }

extension CoreRouter {
    func showRenameWorkoutTemplateModelView(delegate: RenameWorkoutTemplateModelDelegate) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.renameWorkoutTemplateModelView(router: router, delegate: delegate)
        }
    }
}
