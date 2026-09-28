import SwiftUI

@MainActor
protocol ProgramSettingsRouter: GlobalRouter {
    func showRenameProgramView(delegate: RenameWorkoutTemplateModelDelegate)
    func showEditProgramColourIconView(colour: String, icon: String, onSave: @escaping (String, String) -> Void)
    func showEditDayOrderView(dayPlans: [WorkoutTemplateModel], onSave: @escaping ([WorkoutTemplateModel]) -> Void)
    func showEditDeloadView(selected: DeloadType, onSave: @escaping (DeloadType) -> Void)
}

extension CoreRouter: ProgramSettingsRouter {
    func showRenameProgramView(delegate: RenameWorkoutTemplateModelDelegate) {
        router.showScreen(.sheetConfig(config: .compact)) { router in
            builder.renameWorkoutTemplateModelView(router: router, delegate: delegate)
        }
    }

    func showEditProgramColourIconView(colour: String, icon: String, onSave: @escaping (String, String) -> Void) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.editProgramColourIconView(router: router, colour: colour, icon: icon, onSave: onSave)
        }
    }

    func showEditDayOrderView(dayPlans: [WorkoutTemplateModel], onSave: @escaping ([WorkoutTemplateModel]) -> Void) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.editDayOrderView(router: router, dayPlans: dayPlans, onSave: onSave)
        }
    }

    func showEditDeloadView(selected: DeloadType, onSave: @escaping (DeloadType) -> Void) {
        router.showScreen(.sheetConfig(config: .half)) { router in
            builder.editDeloadView(router: router, selected: selected, onSave: onSave)
        }
    }
}
