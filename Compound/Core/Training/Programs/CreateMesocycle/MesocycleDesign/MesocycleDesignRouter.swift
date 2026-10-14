import SwiftUI

@MainActor
protocol MesocycleDesignRouter: GlobalRouter {
    func showRenameWorkoutTemplateModelView(delegate: RenameWorkoutTemplateModelDelegate)
    func showMesocycleSettingsView(mesocycle: Binding<Mesocycle>)
    func showShareToFollowerView(delegate: ShareToFollowerDelegate)
}

extension CoreRouter: MesocycleDesignRouter { }

extension CoreRouter {
    func showRenameWorkoutTemplateModelView(delegate: RenameWorkoutTemplateModelDelegate) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.renameWorkoutTemplateModelView(router: router, delegate: delegate)
        }
    }
}
